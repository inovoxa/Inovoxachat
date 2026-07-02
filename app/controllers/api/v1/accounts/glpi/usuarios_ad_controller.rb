# Consulta de usuário no Active Directory (read-only), para a barra de busca da Visão Geral.
class Api::V1::Accounts::Glpi::UsuariosAdController < Api::V1::Accounts::Glpi::BaseController
  # GET /api/v1/accounts/:account_id/glpi/usuario_ad?login=<login>
  def show
    login = params[:login].to_s.strip
    return render(json: { error: 'informe o login do usuário' }, status: :unprocessable_entity) if login.blank?

    usuario = Glpi::AdUser.new(glpi_config).lookup(login)
    render json: { usuario: usuario }
  rescue StandardError => e
    render json: { error: 'falha ao consultar o usuário no AD', detail: e.message }, status: :bad_gateway
  end
end
