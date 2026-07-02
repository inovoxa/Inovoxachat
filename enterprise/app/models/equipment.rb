# Equipamento disponível para locação. Multi-tenant (account_id).
class Equipment < ApplicationRecord
  enum status: { disponivel: 0, alugado: 1, manutencao: 2 }

  belongs_to :account
  has_many :contract_items, dependent: :destroy
  has_many :contracts, through: :contract_items

  validates :name, presence: true
  validates :serial, uniqueness: { scope: :account_id }, allow_blank: true

  scope :by_status, ->(s) { where(status: s) if s.present? }
  scope :ordered_by_name, -> { order(:name) }
end
