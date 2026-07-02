# CRM — oportunidade do funil de vendas. Multi-tenant (account_id).
# Liga uma Empresa (locação) e um Contato (Chatwoot). Ao "Ganhar", gera um Contrato.
class Opportunity < ApplicationRecord
  enum stage: { novo: 0, qualificado: 1, proposta: 2, ganho: 3, perdido: 4 }

  belongs_to :account
  belongs_to :company, optional: true
  belongs_to :contact, optional: true
  belongs_to :agent, class_name: 'User', optional: true

  validates :name, presence: true
  validates :rating, inclusion: { in: 0..3 }, allow_nil: true

  scope :by_stage, ->(s) { where(stage: s) if s.present? }
  scope :abertas, -> { where.not(stage: [stages[:ganho], stages[:perdido]]) }
  scope :ordered, -> { order(:position, created_at: :desc) }

  # Marca como ganho e (opcionalmente) gera um contrato de locação para a empresa.
  def ganhar!(gerar_contrato: true)
    transaction do
      update!(stage: :ganho, won_at: Time.current)
      gerar_contrato_locacao if gerar_contrato && company_id.present?
    end
  end

  def perder!
    update!(stage: :perdido, lost_at: Time.current)
  end

  private

  def gerar_contrato_locacao
    company.contracts.create!(
      account_id: account_id,
      start_date: Date.current,
      end_date: Date.current + 1.year,
      value: expected_value,
      status: :ativo,
      notes: "Gerado da oportunidade ##{id} — #{name}"
    )
  end
end
