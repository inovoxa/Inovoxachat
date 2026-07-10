# Conexões de calendário do usuário atual (cada um gerencia só as suas).
class Api::V1::Accounts::Calendar::ConnectionsController < Api::V1::Accounts::BaseController
  before_action :fetch_connection, only: [:update, :destroy, :sync]

  def index
    render json: { payload: scoped_connections.map { |connection| serialize(connection) } }
  end

  def update
    permitted = params.require(:connection).permit(:sync_enabled, :external_calendar_id)

    if changing_calendar?(permitted)
      # A agenda alvo mudou: o syncToken/deltaLink e o webhook pertencem à
      # agenda anterior — encerra o webhook antigo, zera o estado incremental
      # e reinicia (novo watch/subscription + full sync na agenda nova).
      unregister_webhook
      @connection.assign_attributes(sync_token: nil, webhook_channel_id: nil, webhook_resource_id: nil,
                                    webhook_subscription_id: nil, webhook_verification_token: nil,
                                    webhook_expires_at: nil)
      permitted[:external_calendar_id] = permitted[:external_calendar_id].to_s.strip.presence
      @connection.assign_attributes(permitted)
      @connection.save!
      Calendar::RegisterWebhookJob.perform_later(@connection.id)
      Calendar::SyncEventsJob.perform_later(@connection.id)
    else
      @connection.update!(permitted.except(:external_calendar_id))
    end

    render json: serialize(@connection)
  end

  def destroy
    # Melhor esforço: encerra o webhook no provedor ANTES de apagar (depois os
    # tokens somem e não há mais como autenticar a chamada de stop).
    unregister_webhook
    @connection.destroy!
    head :ok
  end

  # Sincronização manual imediata (o resultado/erro aparece em last_sync_error).
  def sync
    Calendar::SyncEventsJob.perform_later(@connection.id)
    head :ok
  end

  private

  def scoped_connections
    Current.account.calendar_connections.where(user_id: Current.user.id)
  end

  def fetch_connection
    @connection = scoped_connections.find(params[:id])
  end

  def changing_calendar?(permitted)
    return false unless permitted.key?(:external_calendar_id)

    permitted[:external_calendar_id].to_s.strip != @connection.external_calendar_id.to_s
  end

  def unregister_webhook
    if @connection.google?
      Calendar::Google::WebhookService.new(@connection).stop_existing
    else
      Calendar::Outlook::WebhookService.new(@connection).unregister
    end
  rescue StandardError => e
    Rails.logger.warn("[CalendarWebhook] unregister falhou connection=#{@connection.id}: #{e.message}")
  end

  def serialize(connection)
    {
      id: connection.id,
      provider: connection.provider,
      sync_enabled: connection.sync_enabled,
      external_calendar_id: connection.external_calendar_id,
      last_synced_at: connection.last_synced_at,
      last_sync_error: connection.last_sync_error,
      webhook_expires_at: connection.webhook_expires_at,
      expires_at: connection.expires_at
    }
  end
end
