# Copilot tool: consulta empresas (clientes) da conta — módulo Empresas/locação.
# Read-only, escopado por conta (@assistant.account). Na Fase 1 retorna os dados cadastrais;
# nas fases seguintes será enriquecida com contratos, vencimentos e faturas.
class Captain::Tools::Copilot::CompanyLookupService < Captain::Tools::BaseTool
  STATUS_LABEL = { 'lead' => 'Lead', 'ativo' => 'Cliente ativo',
                   'inativo' => 'Inativo', 'churn' => 'Churn' }.freeze

  def self.name
    'company_lookup'
  end

  description 'Consulta empresas (clientes) da conta pelo nome: status, responsável, CNPJ, ' \
              'telefone, endereço e número de contatos vinculados. Use para perguntas sobre ' \
              'empresas/clientes. Somente leitura.'
  param :nome, type: :string, desc: 'Nome (ou parte do nome/domínio) da empresa a consultar.'

  def execute(nome:)
    return 'Informe o nome da empresa.' if nome.blank?

    companies = @assistant.account.companies.search_by_name_or_domain(nome).limit(10)
    return "Nenhuma empresa encontrada para \"#{nome}\"." if companies.empty?

    companies.map { |c| formatar(c) }.join("\n---\n")
  rescue StandardError => e
    "Erro ao consultar empresas: #{e.message}"
  end

  def active?
    @assistant.account.feature_enabled?('companies')
  end

  private

  def formatar(c)
    [
      "Empresa: #{c.name}",
      "Status: #{STATUS_LABEL[c.status] || c.status}",
      ("Responsável: #{c.account_owner.available_name}" if c.account_owner.present?),
      ("CNPJ: #{c.cnpj}" if c.cnpj.present?),
      ("Telefone: #{c.phone}" if c.phone.present?),
      ("Endereço: #{c.address}" if c.address.present?),
      ("Domínio: #{c.domain}" if c.domain.present?),
      "Contatos vinculados: #{c.contacts_count || 0}"
    ].compact.join("\n")
  end
end
