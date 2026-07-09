# Clients OAuth2 do módulo Calendário. As credenciais vêm da tela de
# Configurações do Calendário (InstallationConfig, com fallback para env var
# de mesmo nome na primeira leitura — ver GlobalConfigService).
module CalendarOauthConcern
  extend ActiveSupport::Concern

  GOOGLE_SCOPE = 'https://www.googleapis.com/auth/calendar.events https://www.googleapis.com/auth/calendar.readonly'.freeze
  OUTLOOK_SCOPE = 'offline_access https://graph.microsoft.com/Calendars.ReadWrite'.freeze

  def calendar_google_client
    ::OAuth2::Client.new(
      GlobalConfigService.load('GOOGLE_CALENDAR_CLIENT_ID', nil),
      GlobalConfigService.load('GOOGLE_CALENDAR_CLIENT_SECRET', nil),
      site: 'https://oauth2.googleapis.com',
      authorize_url: 'https://accounts.google.com/o/oauth2/auth',
      token_url: 'https://oauth2.googleapis.com/token'
    )
  end

  def calendar_outlook_client
    ::OAuth2::Client.new(
      GlobalConfigService.load('MS_GRAPH_CLIENT_ID', nil),
      GlobalConfigService.load('MS_GRAPH_CLIENT_SECRET', nil),
      site: 'https://login.microsoftonline.com',
      authorize_url: 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
      token_url: 'https://login.microsoftonline.com/common/oauth2/v2.0/token'
    )
  end

  def calendar_base_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
  end

  def calendar_redirect_uri(provider)
    path = provider.to_s == 'google' ? 'google' : 'microsoft'
    "#{calendar_base_url}/calendar/#{path}/callback"
  end
end
