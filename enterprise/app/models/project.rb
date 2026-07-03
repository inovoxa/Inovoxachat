# Projeto (estilo Odoo). Multi-tenant (account_id). Opcionalmente ligado a uma empresa.
class Project < ApplicationRecord
  enum status: { aberto: 0, concluido: 1, arquivado: 2 }

  belongs_to :account
  belongs_to :company, optional: true
  has_many :project_tasks, dependent: :destroy

  validates :name, presence: true

  scope :by_status, ->(s) { where(status: s) if s.present? }
  scope :ordered, -> { order(created_at: :desc) }
end
