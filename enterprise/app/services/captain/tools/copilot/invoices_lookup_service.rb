# Copilot tool: consulta financeira (faturas) da conta — pendentes, inadimplência, pagas.
# Read-only, escopado por conta.
class Captain::Tools::Copilot::InvoicesLookupService < Captain::Tools::BaseTool
  def self.name
    'invoices_lookup'
  end

  description 'Consulta financeira da conta: faturas pendentes, inadimplência (vencidas e não ' \
              'pagas) ou pagas. Use para perguntas sobre cobranças, inadimplência e recebimentos. ' \
              'Somente leitura.'
  param :filtro, type: :string, desc: 'pendentes | inadimplencia | pagas. Padrão: inadimplencia.'

  def execute(filtro: 'inadimplencia')
    scope = @assistant.account.invoices.includes(:company)
    faturas = case filtro.to_s
              when 'pendentes' then scope.pendentes
              when 'pagas' then scope.pagas
              else scope.inadimplencia
              end.order(:due_date).limit(20)

    return "Nenhuma fatura para o filtro \"#{filtro}\"." if faturas.empty?

    total = faturas.sum { |f| f.amount.to_f }
    header = "#{faturas.size} fatura(s) — #{filtro} · total R$ #{format('%.2f', total)}:"
    linhas = faturas.map do |f|
      "- #{f.company&.name} | vence #{f.due_date} | R$ #{f.amount} | #{f.situacao}"
    end
    "#{header}\n#{linhas.join("\n")}"
  rescue StandardError => e
    "Erro ao consultar o financeiro: #{e.message}"
  end

  def active?
    @assistant.account.feature_enabled?('companies')
  end
end
