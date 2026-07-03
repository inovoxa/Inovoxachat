# Tarefa de um projeto (Kanban por estágio). Multi-tenant (account_id).
class ProjectTask < ApplicationRecord
  enum stage: { inicio: 0, em_andamento: 1, concluido: 2 }

  belongs_to :account
  belongs_to :project
  belongs_to :assignee, class_name: 'User', optional: true

  validates :title, presence: true
  before_validation :assign_account_from_project, on: :create

  scope :ordered, -> { order(:position, :created_at) }

  private

  def assign_account_from_project
    self.account_id ||= project&.account_id
  end
end
