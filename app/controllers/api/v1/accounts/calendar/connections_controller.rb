# Conexões de calendário do usuário atual (cada um gerencia só as suas).
class Api::V1::Accounts::Calendar::ConnectionsController < Api::V1::Accounts::BaseController
  before_action :fetch_connection, only: [:update, :destroy]

  def index
    render json: { payload: scoped_connections.map { |connection| serialize(connection) } }
  end

  def update
    @connection.update!(params.require(:connection).permit(:sync_enabled))
    render json: serialize(@connection)
  end

  def destroy
    # Melhor esforço: encerra o webhook no provedor ANTES de apagar (depois os
    # tokens somem e não há mais como autenticar a chamada de stop).
    unregister_webhook
    @connection.destroy!
    head :ok
  end

  private

  def scoped_connections
    Current.account.calendar_connections.where(user_id: Current.user.id)
  end

  def fetch_connection
    @connection = scoped_connections.find(params[:id])
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
      last_synced_at: connection.last_synced_at,
      webhook_expires_at: connection.webhook_expires_at,
      expires_at: connection.expires_at
    }
  end
end
