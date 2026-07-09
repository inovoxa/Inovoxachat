# Inicia o consentimento OAuth do calendário para o usuário atual.
# Qualquer membro (admin ou agente) conecta o próprio calendário; o state é um
# sgid assinado do AccountUser (leva conta+usuário ao callback, à prova de adulteração).
class Api::V1::Accounts::Calendar::AuthorizationsController < Api::V1::Accounts::BaseController
  include CalendarOauthConcern

  def create
    provider = params[:provider].to_s
    return render json: { success: false, error: 'invalid provider' }, status: :unprocessable_entity unless
      CalendarConnection.providers.key?(provider)

    url = authorize_url_for(provider)
    if url
      render json: { success: true, url: url }
    else
      render json: { success: false }, status: :unprocessable_entity
    end
  end

  private

  def authorize_url_for(provider)
    client = provider == 'google' ? calendar_google_client : calendar_outlook_client
    return nil if client.id.blank?

    options = {
      redirect_uri: calendar_redirect_uri(provider),
      scope: provider == 'google' ? CalendarOauthConcern::GOOGLE_SCOPE : CalendarOauthConcern::OUTLOOK_SCOPE,
      response_type: 'code',
      state: state
    }
    # Google só devolve refresh_token com consent explícito + acesso offline.
    options.merge!(prompt: 'consent', access_type: 'offline') if provider == 'google'

    client.auth_code.authorize_url(options)
  end

  def state
    Current.account_user.to_sgid(expires_in: 15.minutes, for: 'calendar_oauth').to_s
  end
end
