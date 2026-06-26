# Aprovadores de chamado: membros do grupo do AD "Aprovadores GLPI", via SSH/PowerShell
# (Gerenciar_Aprovadores.ps1). Porta backend/src/routes/aprovadores.js + ad/aprovadores.js.
class Api::V1::Accounts::Glpi::AprovadoresController < Api::V1::Accounts::Glpi::BaseController
  SAFE_LOGIN = /\A[A-Za-z0-9._\-\\ ]{1,128}\z/

  # GET /api/v1/accounts/:account_id/glpi/aprovadores
  def index
    data = run_script('-Action List')
    render json: { grupo: data['grupo'] || 'Aprovadores GLPI', membros: data['membros'] || [] }
  rescue StandardError => e
    render json: { error: 'falha ao consultar o AD', detail: e.message }, status: :bad_gateway
  end

  # POST /api/v1/accounts/:account_id/glpi/aprovadores  { login }
  def create
    login = params[:login].to_s.strip
    return render(json: { error: 'login inválido' }, status: :unprocessable_entity) unless login.match?(SAFE_LOGIN)

    data = run_script(%(-Action Add -Login "#{login.delete('"')}"))
    render json: { ok: true, grupo: data['grupo'], membros: data['membros'] || [] }
  rescue StandardError => e
    render json: { error: 'falha ao adicionar no AD', detail: e.message }, status: :bad_gateway
  end

  # DELETE /api/v1/accounts/:account_id/glpi/aprovadores/:login
  def destroy
    login = params[:login].to_s.strip
    return render(json: { error: 'login inválido' }, status: :unprocessable_entity) unless login.match?(SAFE_LOGIN)

    data = run_script(%(-Action Remove -Login "#{login.delete('"')}"))
    render json: { ok: true, grupo: data['grupo'], membros: data['membros'] || [] }
  rescue StandardError => e
    render json: { error: 'falha ao remover no AD', detail: e.message }, status: :bad_gateway
  end

  private

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
