# Configuração da integração GLPI por conta (multi-empresa).
# show/status: qualquer usuário autenticado da conta. update: somente admin.
# O service_token NUNCA é devolvido (apenas se está presente).
class Api::V1::Accounts::Glpi::ConfigsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?, only: [:update]

  # GET /api/v1/accounts/:account_id/glpi/config
  def show
    render json: serialize(find_or_build)
  end

  # PATCH /api/v1/accounts/:account_id/glpi/config
  def update
    cfg = find_or_build
    attrs = config_params.to_h
    attrs.delete('service_token') if attrs['service_token'].blank? # não apagar token ao salvar sem alterá-lo
    cfg.assign_attributes(attrs)
    cfg.save!
    render json: serialize(cfg)
  end

  # GET /api/v1/accounts/:account_id/glpi/config/status  (usado pelo menu)
  def status
    cfg = GlpiAccountConfig.find_by(account_id: current_account.id)
    render json: { enabled: cfg&.usable? || false }
  end

  private

  def find_or_build
    GlpiAccountConfig.find_or_initialize_by(account_id: current_account.id)
  end

  def config_params
    params.require(:config).permit(:enabled, :central_url, :service_token)
  end

  def serialize(cfg)
    {
      enabled: cfg.enabled,
      central_url: cfg.central_url,
      has_token: cfg.service_token.present?
    }
  end
end
