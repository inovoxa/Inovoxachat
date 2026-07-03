# Planejamento — turno alocado a um recurso (agente). Multi-tenant (account_id).
class PlanningShift < ApplicationRecord
  enum status: { provisorio: 0, agendado: 1, em_progresso: 2, concluido: 3 }

  belongs_to :account
  belongs_to :company, optional: true
  belongs_to :resource, class_name: 'User', optional: true

  validates :start_at, presence: true

  scope :on_day, lambda { |date|
    d = date.to_date.beginning_of_day
    where(start_at: d..(d + 1.day))
  }
  scope :ordered, -> { order(:start_at) }
end
