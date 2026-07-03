# Linha de uma cotação: produto/equipamento com qtd, preço, desconto e imposto.
# is_section=true representa um cabeçalho de seção (sem valores). Multi-tenant.
class QuotationLine < ApplicationRecord
  belongs_to :account
  belongs_to :quotation
  belongs_to :equipment, optional: true

  validates :name, presence: true
  validates :qty, :unit_price, numericality: true, allow_nil: true

  before_validation :assign_account_from_quotation, on: :create
  before_save :recompute_amount

  # Valor da linha: qtd * preço, aplicando desconto e imposto.
  def total
    return 0 if is_section

    base = qty.to_d * unit_price.to_d
    base -= base * (discount_percent.to_d / 100)
    base += base * (tax_percent.to_d / 100)
    base.round(2)
  end

  private

  def recompute_amount
    self.amount = is_section ? 0 : total
  end

  def assign_account_from_quotation
    self.account_id ||= quotation&.account_id
  end
end
