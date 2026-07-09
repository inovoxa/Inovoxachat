# Callback OAuth do calendário: troca o code por tokens, faz upsert da
# CalendarConnection do usuário e dispara o registro do webhook + primeiro sync.
class Calendar::BaseCallbacksController < ApplicationController
  include CalendarOauthConcern

  def show
    token = oauth_client.auth_code.get_token(
      params[:code],
      redirect_uri: calendar_redirect_uri(provider_name)
    )
    upsert_connection(token)
    Calendar::RegisterWebhookJob.perform_later(@connection.id)
    Calendar::SyncEventsJob.perform_later(@connection.id)
    redirect_to settings_url
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
    redirect_to '/'
  end

  private

  def provider_name
    raise NotImplementedError
  end

  def oauth_client
    raise NotImplementedError
  end

  def account_user
    @account_user ||= begin
      raise ActionController::BadRequest, 'Missing state variable' if params[:state].blank?

      record = GlobalID::Locator.locate_signed(params[:state], for: 'calendar_oauth')
      raise 'Invalid or expired state' if record.nil?

      record
    end
  end

  def upsert_connection(token)
    @connection = CalendarConnection.find_or_initialize_by(user_id: account_user.user_id, provider: provider_name)
    @connection.account_id = account_user.account_id
    @connection.access_token = token.token
    # Alguns provedores não reenviam o refresh_token em reconexões — preserva o antigo.
    @connection.refresh_token = token.refresh_token if token.refresh_token.present?
    @connection.expires_at = token.expires_at.present? ? Time.at(token.expires_at).utc : 1.hour.from_now
    @connection.sync_enabled = true
    @connection.save!
  end

  def settings_url
    "#{calendar_base_url}/app/accounts/#{account_user.account_id}/settings/calendar/integrations"
  end
end
