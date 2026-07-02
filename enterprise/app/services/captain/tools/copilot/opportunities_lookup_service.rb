# Copilot tool: consulta o funil de vendas (CRM). Read-only, escopado por conta.
class Captain::Tools::Copilot::OpportunitiesLookupService < Captain::Tools::BaseTool
  STAGE_LABEL = { 'novo' => 'Novo', 'qualificado' => 'Qualificado', 'proposta' => 'Proposta',
                  'ganho' => 'Ganho', 'perdido' => 'Perdido' }.freeze

  def self.name
    'opportunities_lookup'
  end

  description 'Consulta o funil de vendas (CRM): oportunidades por estágio, valor em aberto, ' \
              'ou lista por estágio. Use para perguntas sobre vendas, funil e oportunidades. ' \
              'Somente leitura.'
  param :stage, type: :string,
                desc: 'novo | qualificado | proposta | ganho | perdido. Vazio = resumo do funil.'

  def execute(stage: nil)
    scope = @assistant.account.opportunities.includes(:company)
    stage.present? ? listar(scope, stage) : resumo(scope)
  rescue StandardError => e
    "Erro ao consultar o funil: #{e.message}"
  end

  def active?
    @assistant.account.feature_enabled?('companies')
  end

  private

  def listar(scope, stage)
    ops = scope.by_stage(stage).ordered.limit(20)
    return "Nenhuma oportunidade no estágio \"#{stage}\"." if ops.empty?

    linhas = ops.map do |o|
      "- #{o.name} | #{o.company&.name} | R$ #{o.expected_value} | #{STAGE_LABEL[o.stage] || o.stage}"
    end
    "Oportunidades — #{STAGE_LABEL[stage] || stage} (#{ops.size}):\n#{linhas.join("\n")}"
  end

  def resumo(scope)
    por = Hash.new(0)
    scope.find_each { |o| por[STAGE_LABEL[o.stage] || o.stage] += 1 }
    return 'Nenhuma oportunidade no funil.' if por.empty?

    aberto = scope.abertas.sum(:expected_value)
    "Funil de vendas — #{por.map { |k, v| "#{k}: #{v}" }.join(', ')}. " \
      "Valor em aberto: R$ #{aberto}."
  end
end
