# Cotação de venda/locação (módulo Empresas). Multi-tenant (account_id).
# Fluxo: cotacao -> enviada -> pedido (gera Contrato). Inspirado no Odoo Vendas.
class Quotation < ApplicationRecord
  enum status: { cotacao: 0, enviada: 1, pedido: 2, cancelada: 3 }
  enum recurring_plan: { nenhum: 0, mensalmente: 1, trimestralmente: 2, semestralmente: 3, anualmente: 4 }

  belongs_to :account
  belongs_to :company, optional: true
  belongs_to :contact, optional: true
  belongs_to :agent, class_name: 'User', optional: true
  belongs_to :opportunity, optional: true
  has_many :quotation_lines, -> { order(:position) }, dependent: :destroy

  accepts_nested_attributes_for :quotation_lines, allow_destroy: true

  validates :number, presence: true, uniqueness: { scope: :account_id }

  before_validation :assign_number, on: :create
  before_save :recompute_total

  scope :by_status, ->(s) { where(status: s) if s.present? }
  scope :for_company, ->(company_id) { where(company_id: company_id) if company_id.present? }
  scope :ordered, -> { order(created_at: :desc) }

  # Confirma a cotação como pedido de venda e (opcionalmente) gera um contrato de locação.
  def confirmar!(gerar_contrato: true)
    transaction do
      update!(status: :pedido)
      gerar_contrato_locacao if gerar_contrato && company_id.present?
    end
  end

  def recompute_total
    self.amount_total = quotation_lines.reject(&:is_section).reject(&:marked_for_destruction?).sum(&:total)
  end

  private

  def assign_number
    return if number.present?

    seq = (account&.quotations&.where('number ~ ?', '^S[0-9]+$')&.maximum(Arel.sql("CAST(SUBSTRING(number FROM 2) AS INTEGER)")) || 0) + 1
    self.number = format('S%05d', seq)
  end

  def gerar_contrato_locacao
    company.contracts.create!(
      account_id: account_id,
      start_date: delivery_date || Date.current,
      end_date: recurring_until || (Date.current + 1.year),
      value: amount_total,
      status: :ativo,
      notes: "Gerado da cotação #{number}"
    )
  end
end
