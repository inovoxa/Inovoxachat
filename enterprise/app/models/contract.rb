# Contrato de locação de uma empresa (cliente). Multi-tenant (account_id).
class Contract < ApplicationRecord
  enum status: { ativo: 0, vencido: 1, encerrado: 2, renovacao_pendente: 3 }

  belongs_to :account
  belongs_to :company
  has_many :contract_items, dependent: :destroy
  has_many :equipments, through: :contract_items

  accepts_nested_attributes_for :contract_items, allow_destroy: true

  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_after_start

  before_validation :assign_account_from_company, on: :create

  scope :by_status, ->(s) { where(status: s) if s.present? }
  scope :for_company, ->(company_id) { where(company_id: company_id) if company_id.present? }
  # Contratos ativos que vencem entre hoje e +N dias (submenu "A vencer").
  scope :vencendo_em, lambda { |dias|
    ativo.where(end_date: Date.current..(Date.current + dias.to_i.days))
  }
  # Ativos cuja data de término já passou (submenu "Vencidos").
  scope :vencidos_por_data, -> { where('end_date < ?', Date.current) }

  def vencido_por_data?
    end_date.present? && end_date < Date.current
  end

  private

  def assign_account_from_company
    self.account_id ||= company&.account_id
  end

  def end_after_start
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, 'deve ser posterior à data de início') if end_date < start_date
  end
end
