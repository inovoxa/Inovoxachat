# Fatura de uma empresa/contrato (módulo Empresas — financeiro). Multi-tenant (account_id).
# Situação real deriva de paid_at + due_date (fonte da verdade); status enum é informativo.
class Invoice < ApplicationRecord
  enum status: { pendente: 0, pago: 1, atrasado: 2 }

  belongs_to :account
  belongs_to :company
  belongs_to :contract, optional: true

  validates :due_date, presence: true
  before_validation :assign_account_from_company, on: :create

  scope :by_status, ->(s) { where(status: s) if s.present? }
  scope :for_company, ->(company_id) { where(company_id: company_id) if company_id.present? }
  scope :pendentes, -> { where(paid_at: nil).where('due_date >= ?', Date.current) }
  scope :inadimplencia, -> { where(paid_at: nil).where('due_date < ?', Date.current) }
  scope :pagas, -> { where.not(paid_at: nil) }
  scope :vencendo_em, lambda { |dias|
    where(paid_at: nil, due_date: Date.current..(Date.current + dias.to_i.days))
  }

  def atrasada?
    paid_at.nil? && due_date.present? && due_date < Date.current
  end

  # Situação derivada para exibição: pago | atrasado | pendente.
  def situacao
    return 'pago' if paid_at.present?

    atrasada? ? 'atrasado' : 'pendente'
  end

  def pagar!
    update!(paid_at: Time.current, status: :pago)
  end

  private

  def assign_account_from_company
    self.account_id ||= company&.account_id
  end
end
