# Chamados e Kanban: proxy para /api/tickets da Central da conta.
class Api::V1::Accounts::Glpi::TicketsController < Api::V1::Accounts::Glpi::BaseController
  # GET /api/v1/accounts/:account_id/glpi/tickets
  def index
    proxy_to_central(:get, '/api/tickets', query: index_params)
  end

  # PATCH /api/v1/accounts/:account_id/glpi/tickets/:id/status  (mover card no Kanban)
  def status
    proxy_to_central(:patch, "/api/tickets/#{params[:id].to_i}/status",
                     body: { status: params[:status] })
  end

  private

  def index_params
    params.permit(:search, :period, :sector, :limit).to_h
  end
end
