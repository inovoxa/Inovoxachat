# Chamados e Kanban: conexão direta ao MySQL do GLPI (requer gem mysql2 — próxima fase).
class Api::V1::Accounts::Glpi::TicketsController < Api::V1::Accounts::Glpi::BaseController
  def index
    not_implemented_yet(tickets: [], total: 0)
  end

  def status
    not_implemented_yet
  end
end
