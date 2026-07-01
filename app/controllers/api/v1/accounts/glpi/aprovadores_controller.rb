# Aprovadores de chamado: a lista é mantida NO CHATWOOT (glpi_account_configs.settings['_aprovadores'])
# e só é aplicada no grupo do AD ("Aprovadores GLPI") ao clicar em Sincronizar.
# Cada item: { login, nome, status }  status ∈ synced | pending_add | pending_remove.
# O AD é tocado apenas em #sync e #import (via SSH/Gerenciar_Aprovadores.ps1).
class Api::V1::Accounts::Glpi::AprovadoresController < Api::V1::Accounts::Glpi::BaseController
  SAFE_LOGIN = /\A[A-Za-z0-9._\-\\ ]{1,128}\z/
  STORE_KEY = '_aprovadores'.freeze
  GRUPO = 'Aprovadores GLPI'.freeze

  # GET /aprovadores — lê do Chatwoot, NÃO consulta o AD. Auto-corrige itens malformados.
  def index
    bruta = (glpi_config.settings || {})[STORE_KEY] || []
    norm = bruta.map { |i| normalizar_item(i) }
    salvar(norm) if norm != bruta
    render json: { grupo: GRUPO, membros: norm }
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

  # POST /aprovadores/sync — aplica as pendências no AD (add/remove) e, em seguida,
  # RECARREGA a lista a partir do grupo do AD (mesma lógica do Importar) — a lista final
  # sempre reflete o AD, com dados atualizados. Erros por login vão em "resultados".
  def sync
    resultados = []
    lista.each do |item|
      case item['status']
      when 'pending_add'    then resultados << aplicar_ad('Add', item['login'])
      when 'pending_remove' then resultados << aplicar_ad('Remove', item['login'])
      end
    end
    membros = importar_do_ad
    salvar(membros)
    render json: { membros: membros, resultados: resultados }
  rescue StandardError => e
    render json: { error: 'falha ao sincronizar com o AD', detail: e.message }, status: :bad_gateway
  end

  # GET /aprovadores/import — SUBSTITUI a lista pelos membros atuais do grupo no AD.
  def import
    membros = importar_do_ad
    salvar(membros)
    render json: { grupo: GRUPO, membros: membros }
  rescue StandardError => e
    render json: { error: 'falha ao importar do AD', detail: e.message }, status: :bad_gateway
  end

  private

  # Aplica uma ação (Add/Remove) para um login no AD; nunca levanta — devolve o resultado.
  def aplicar_ad(action, login)
    run_script(%(-Action #{action} -Login "#{sanitize(login)}"))
    { login: login, acao: action.downcase, ok: true }
  rescue StandardError => e
    { login: login, acao: action.downcase, ok: false, erro: e.message }
  end

  # Reconstrói a lista a partir do grupo do AD (fonte da verdade); todos status synced.
  def importar_do_ad
    data = run_script('-Action List')
    vistos = {}
    nova = []
    (data['membros'] || []).each do |m|
      login = (m.is_a?(Hash) ? m['login'] : m).to_s.strip
      key = login.downcase
      next if login.blank? || vistos[key]

      vistos[key] = true
      nova << item_do_ad(m, login)
    end
    nova
  end

  def lista
    ((glpi_config.settings || {})[STORE_KEY] || []).map { |i| normalizar_item(i) }
  end

  AD_FIELDS = %w[nome email departamento office mobile habilitado].freeze

  # Monta um item a partir de um membro do AD
  # (objeto {login,nome,email,departamento,office,mobile,habilitado}).
  def item_do_ad(m, login)
    base = { 'login' => login, 'status' => 'synced' }
    return base.merge('nome' => nil) unless m.is_a?(Hash)

    base.merge(
      'nome' => m['nome'].presence,
      'email' => m['email'].presence,
      'departamento' => m['departamento'].presence,
      'office' => m['office'].presence,
      'mobile' => m['mobile'].presence,
      'habilitado' => m['habilitado']
    )
  end

  # Conserta itens cujo 'login' virou o objeto inteiro do AD serializado (bug do import antigo):
  # extrai o login/nome reais de uma string tipo {"login" => "teste.ti", "nome" => "Teste TI", ...}.
  def normalizar_item(item)
    login = item['login'].to_s
    nome = item['nome']
    extras = item.slice(*AD_FIELDS).except('nome')
    unless login.match?(SAFE_LOGIN)
      extraido = login[/["']login["']\s*(?:=>|:)\s*["']([^"']+)["']/, 1]
      if extraido
        nome ||= login[/["']nome["']\s*(?:=>|:)\s*["']([^"']+)["']/, 1]
        extras['email'] ||= login[/["']email["']\s*(?:=>|:)\s*["']([^"']+)["']/, 1]
        extras['departamento'] ||= login[/["']departamento["']\s*(?:=>|:)\s*["']([^"']+)["']/, 1]
        login = extraido
      end
    end
    { 'login' => login, 'nome' => nome.presence, 'status' => item['status'].presence || 'synced' }
      .merge(extras.compact)
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
