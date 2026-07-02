# Copilot tool: consulta um usuário no Active Directory (read-only) via SSH.
class Captain::Tools::Copilot::AdUserService < Captain::Tools::BaseTool
  def self.name
    'ad_user_lookup'
  end

  description 'Consulta um usuário no Active Directory (AD) da empresa pelo login (samAccountName). ' \
              'Retorna grupos, status (ativo/bloqueado), datas (criação, último logon, troca de senha), ' \
              'tentativas de login sem sucesso, OU/árvore, e-mail, mobile, departamento, cargo, ' \
              'organization e logon script. Use para perguntas sobre usuários/contas do AD.'
  param :login, type: :string, desc: 'Login do usuário no AD (nome de usuário / samAccountName).'

  def execute(login:)
    cfg = glpi_config
    return 'Integração com o AD não configurada para esta conta.' unless cfg&.usable?

    u = Glpi::AdUser.new(cfg).lookup(login)
    formatar(u)
  rescue StandardError => e
    "Erro ao consultar o usuário no AD: #{e.message}"
  end

  def active?
    glpi_config&.usable? || false
  end

  private

  def glpi_config
    GlpiAccountConfig.find_by(account_id: @assistant.account_id)
  end

  def formatar(u)
    status = u['habilitado'] ? 'Ativo' : 'Desativado'
    status += ' (bloqueado)' if u['bloqueado']
    linhas = [
      "Usuário: #{u['nome']} (#{u['login']})",
      "Status: #{status}",
      ("E-mail: #{u['email']}" if u['email'].present?),
      ("Mobile: #{u['mobile']}" if u['mobile'].present?),
      ("Departamento: #{u['departamento']}" if u['departamento'].present?),
      ("Cargo: #{u['cargo']}" if u['cargo'].present?),
      ("Organization: #{u['organization']}" if u['organization'].present?),
      ("Escritório: #{u['escritorio']}" if u['escritorio'].present?),
      ("Logon script: #{u['logon_script']}" if u['logon_script'].present?),
      ("Criado em: #{u['data_criacao']}" if u['data_criacao'].present?),
      ("Último logon: #{u['ultimo_logon_ad']}" if u['ultimo_logon_ad'].present?),
      ("Última troca de senha: #{u['ultima_troca_senha']}" if u['ultima_troca_senha'].present?),
      ("Logins sem sucesso: #{u['logins_sem_sucesso']}" unless u['logins_sem_sucesso'].nil?),
      ("Árvore/OU: #{u['arvore']}" if u['arvore'].present?),
      ("Grupos: #{Array(u['grupos']).join(', ')}" if Array(u['grupos']).any?)
    ].compact
    linhas.join("\n")
  end
end
