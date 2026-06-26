# Agente IA: proxy para /api/agente da Central da conta.
class Api::V1::Accounts::Glpi::AgenteController < Api::V1::Accounts::Glpi::BaseController
  # GET /api/v1/accounts/:account_id/glpi/agente
  def show
    proxy_to_central(:get, '/api/agente', query: params.permit(:period).to_h)
  end
end
