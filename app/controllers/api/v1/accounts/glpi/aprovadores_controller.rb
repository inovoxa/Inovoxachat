# Aprovadores de chamado: a lista é mantida NO CHATWOOT (glpi_account_configs.settings['_aprovadores'])
# e só é aplicada no grupo do AD ("Aprovadores GLPI") ao clicar em Sincronizar.
# Cada item: { login, nome, status }  status ∈ synced | pending_add | pending_remove.
# O AD é tocado apenas em #sync e #import (via SSH/Gerenciar_Aprovadores.ps1).
class Api::V1::Accounts::Glpi::AprovadoresController < Api::V1::Accounts::Glpi::BaseController
  SAFE_LOGIN = /\A[A-Za-z0-9._\-\\ ]{1,128}\z/
  STORE_KEY = '_aprovadores'.freeze
  GRUPO = 'Aprovadores GLPI'.freeze

  # GET /aprovadores — lê do Chatwoot, NÃO consulta o AD.
  def index
    render json: { grupo: GRUPO, membros: lista }
  end

  # POST /aprovadores  { login, nome? } — só grava no Chatwoot (pendente de sync).
  def create
    login = params[:login].to_s.strip
    nome = params[:nome].to_s.strip
    return render(json: { error: 'login inválido' }, status: :unprocessable_entity) unless login.match?(SAFE_LOGIN)

    atual = lista
    if atual.any? { |i| same_login?(i['login'], login) }
      return render(json: { error: 'este usuário já está na lista' }, status: :unprocessable_entity)
    end

    atual << { 'login' => login, 'nome' => nome.presence, 'status' => 'pending_add' }
    salvar(atual)
    render json: { ok: true, membros: atual }
  end

  # DELETE /aprovadores/:login — remove no Chatwoot (marca para remover no AD se já estava lá).
  def destroy
    login = params[:login].to_s.strip
    atual = lista
    item = atual.find { |i| same_login?(i['login'], login) }
    return render(json: { error: 'usuário não encontrado' }, status: :not_found) unless item

    if item['status'] == 'pending_add'
      atual.reject! { |i| same_login?(i['login'], login) } # nunca foi pro AD: some direto
    else
      item['status'] = 'pending_remove' # estava no AD: marca para remover no sync
    end
    salvar(atual)
    render json: { ok: true, membros: atual }
  end

  # POST /aprovadores/sync — aplica as pendências no AD (add/remove) via SSH.
  def sync
    nova = []
    resultados = []
    lista.each do |item|
      case item['status']
      when 'pending_add'
        aplicar(item, nova, resultados, 'Add', 'add') { item['status'] = 'synced'; nova << item }
      when 'pending_remove'
        aplicar(item, nova, resultados, 'Remove', 'remove') { nil } # sucesso = sai da lista
      else
        nova << item
      end
    end
    salvar(nova)
    render json: { membros: nova, resultados: resultados }
  end

  # GET /aprovadores/import — puxa os membros atuais do AD e mescla na lista (status synced).
  def import
    data = run_script('-Action List')
    atual = lista
    (data['membros'] || []).each do |login|
      next if atual.any? { |i| same_login?(i['login'], login) }

      atual << { 'login' => login.to_s, 'nome' => nil, 'status' => 'synced' }
    end
    salvar(atual)
    render json: { grupo: data['grupo'] || GRUPO, membros: atual }
  rescue StandardError => e
    render json: { error: 'falha ao importar do AD', detail: e.message }, status: :bad_gateway
  end

  private

  # Executa a ação no AD; em erro mantém o item pendente e registra o motivo.
  def aplicar(item, nova, resultados, ps_action, label)
    run_script(%(-Action #{ps_action} -Login "#{sanitize(item['login'])}"))
    resultados << { login: item['login'], acao: label, ok: true }
    yield
  rescue StandardError => e
    nova << item
    resultados << { login: item['login'], acao: label, ok: false, erro: e.message }
  end

  def lista
    (glpi_config.settings || {})[STORE_KEY] || []
  end

  def salvar(novos)
    cfg = glpi_config
    cfg.settings = (cfg.settings || {}).merge(STORE_KEY => novos)
    cfg.save!
  end

  def same_login?(a, b)
    a.to_s.strip.casecmp?(b.to_s.strip)
  end

  def sanitize(login)
    raise 'login inválido' unless login.to_s.match?(SAFE_LOGIN)

    login.to_s.delete('"')
  end

  def run_script(args)
    script = glpi_config.effective_settings['AD_APROVADORES_SCRIPT'].presence ||
             'C:\\Scripts\\Gerenciar_Aprovadores.ps1'
    cmd = %(powershell -NoProfile -ExecutionPolicy Bypass -File "#{script}" #{args})
    parse(Glpi::SshClient.new(glpi_config).run(cmd))
  end

  def parse(raw)
    obj = JSON.parse(raw.to_s.strip)
    raise obj['erro'] if obj.is_a?(Hash) && obj['erro'].present?

    obj
  rescue JSON::ParserError
    raise 'resposta inválida do AD'
  end
end
