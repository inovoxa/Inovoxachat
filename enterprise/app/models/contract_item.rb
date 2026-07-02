# Item de contrato: um equipamento (com quantidade) vinculado a um contrato de locação.
class ContractItem < ApplicationRecord
  belongs_to :account
  belongs_to :contract
  belongs_to :equipment

  validates :qty, numericality: { greater_than: 0 }
  before_validation :assign_account_from_contract, on: :create

  private

  def assign_account_from_contract
    self.account_id ||= contract&.account_id
  end
end
