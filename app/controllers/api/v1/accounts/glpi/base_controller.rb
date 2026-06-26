# Base do módulo GLPI: resolve a config da conta (multi-empresa).
# A conexão direta (MySQL GLPI, PostgreSQL n8n, AD SSH) é feita pelos controllers
# filhos usando as variáveis de glpi_config.effective_settings / secret(...).
class Api::V1::Accounts::Glpi::BaseController < Api::V1::Accounts::BaseController
  before_action :ensure_glpi_enabled

  private

  def glpi_config
    @glpi_config ||= GlpiAccountConfig.find_by(account_id: current_account.id)
  end

  def ensure_glpi_enabled
    return if glpi_config&.usable?

    render json: { error: 'integração GLPI não configurada para esta conta' }, status: :not_found
  end

  # Placeholder enquanto a conexão direta de cada tela não está implementada.
  def not_implemented_yet(extra = {})
    render json: { error: 'em construção (conexão direta ao GLPI em implementação)' }.merge(extra),
           status: :not_implemented
  end
end
