# Copilot tool: consulta contratos de locação da conta (a vencer / vencidos / ativos).
# Read-only, escopado por conta (@assistant.account).
class Captain::Tools::Copilot::ContractsLookupService < Captain::Tools::BaseTool
  def self.name
    'contracts_lookup'
  end

  description 'Consulta contratos de locação da conta: a vencer (próximos N dias), vencidos ou ' \
              'ativos. Use para perguntas sobre vencimentos, prazos e contratos. Somente leitura.'
  param :filtro, type: :string, desc: 'a_vencer | vencidos | ativos. Padrão: a_vencer.'
  param :dias, type: :number, desc: 'Janela em dias quando filtro=a_vencer (padrão 30).'

  def execute(filtro: 'a_vencer', dias: 30)
    scope = @assistant.account.contracts.includes(:company)
    contratos = case filtro.to_s
                when 'vencidos' then scope.vencidos_por_data
                when 'ativos' then scope.ativo
                else scope.vencendo_em(dias || 30)
                end.order(:end_date).limit(20)

    return "Nenhum contrato para o filtro \"#{filtro}\"." if contratos.empty?

    janela = filtro.to_s == 'a_vencer' ? " (próximos #{dias || 30} dias)" : ''
    header = "#{contratos.size} contrato(s) — #{filtro}#{janela}:"
    linhas = contratos.map do |c|
      "- ##{c.id} | #{c.company&.name} | vence #{c.end_date} | R$ #{c.value} | #{c.status}"
    end
    "#{header}\n#{linhas.join("\n")}"
  rescue StandardError => e
    "Erro ao consultar contratos: #{e.message}"
  end

  def active?
    @assistant.account.feature_enabled?('companies')
  end
end
