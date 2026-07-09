# Credenciais OAuth do módulo Calendário, inseridas pela UI de Configurações.
# Persistidas em InstallationConfig (mesmo store das credenciais dos canais de
# e-mail). O secret é write-only: nunca é devolvido, apenas `secret_present`.
class Api::V1::Accounts::Calendar::OauthConfigsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  KEYS = {
    'google' => { client_id: 'GOOGLE_CALENDAR_CLIENT_ID', client_secret: 'GOOGLE_CALENDAR_CLIENT_SECRET' },
    'outlook' => { client_id: 'MS_GRAPH_CLIENT_ID', client_secret: 'MS_GRAPH_CLIENT_SECRET' }
  }.freeze

  def show
    render json: KEYS.transform_values { |keys|
      {
        client_id: GlobalConfigService.load(keys[:client_id], nil),
        secret_present: GlobalConfigService.load(keys[:client_secret], nil).present?
      }
    }
  end

  def update
    KEYS.each do |provider, keys|
      write_config(keys[:client_id], params.dig(provider, :client_id))
      write_config(keys[:client_secret], params.dig(provider, :client_secret))
    end
    show
  end

  private

  # Grava apenas quando o valor vem preenchido — enviar em branco preserva o
  # que está salvo (necessário para o secret write-only não ser apagado).
  def write_config(name, value)
    return if value.blank?

    config = InstallationConfig.where(name: name).first_or_initialize(locked: false)
    config.value = value.to_s.strip
    config.save!
    GlobalConfig.clear_cache
  end
end
