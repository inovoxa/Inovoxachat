# Copilot tool: consulta cotações/pedidos de venda da conta (Vendas).
# Read-only, escopado por conta (@assistant.account).
class Captain::Tools::Copilot::QuotationsLookupService < Captain::Tools::BaseTool
  def self.name
    'quotations_lookup'
  end

  description 'Consulta cotações e pedidos de venda de locação da conta. Filtre por status ' \
              '(cotacao, enviada, pedido, cancelada) e opcionalmente por empresa. Use para ' \
              'perguntas sobre propostas, valores e pedidos. Somente leitura.'
  param :status, type: :string, desc: 'cotacao | enviada | pedido | cancelada. Opcional.'
  param :empresa, type: :string, desc: 'Nome (ou parte) da empresa cliente. Opcional.'

  def execute(status: nil, empresa: nil)
    scope = @assistant.account.quotations.includes(:company, :agent).ordered
    scope = scope.by_status(status) if status.present?
    if empresa.present?
      ids = @assistant.account.companies.where('name ILIKE ?', "%#{empresa}%").select(:id)
      scope = scope.where(company_id: ids)
    end
    cotacoes = scope.limit(20)

    return 'Nenhuma cotação encontrada para o filtro informado.' if cotacoes.empty?

    header = "#{cotacoes.size} cotação(ões):"
    linhas = cotacoes.map do |q|
      cliente = q.company&.name || 'sem empresa'
      "- #{q.number} | #{cliente} | #{q.status} | R$ #{q.amount_total} | exp. #{q.expiration_date || '—'}"
    end
    "#{header}\n#{linhas.join("\n")}"
  rescue StandardError => e
    "Erro ao consultar cotações: #{e.message}"
  end

  def active?
    @assistant.account.feature_enabled?('companies')
  end
end
