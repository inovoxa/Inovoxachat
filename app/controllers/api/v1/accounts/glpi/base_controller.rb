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

  PERIOD_DAYS = { '7d' => 7, '30d' => 30, '90d' => 90, '180d' => 180 }.freeze

  # Intervalo [from, to] (Time) a partir dos params: 'from'/'to' (datas YYYY-MM-DD) têm
  # prioridade; senão usa 'period' (preset); padrão = 180 dias.
  def date_range
    if params[:from].present? && params[:to].present?
      from = (Time.zone.parse(params[:from].to_s) rescue nil) || 180.days.ago
      to = ((Time.zone.parse(params[:to].to_s) rescue nil) || Time.current).end_of_day
      from <= to ? [from, to] : [to.beginning_of_day, from.end_of_day]
    else
      n = PERIOD_DAYS[params[:period]] || 90
      [n.days.ago, Time.current]
    end
  end

  # Placeholder enquanto a conexão direta de cada tela não está implementada.
  def not_implemented_yet(extra = {})
    render json: { error: 'em construção (conexão direta ao GLPI em implementação)' }.merge(extra),
           status: :not_implemented
  end
end
