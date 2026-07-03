# Ordem de reparo (estilo Odoo Repair). Multi-tenant (account_id).
class RepairOrder < ApplicationRecord
  enum stage: { novo: 0, confirmado: 1, em_reparo: 2, reparado: 3 }

  belongs_to :account
  belongs_to :company, optional: true
  belongs_to :equipment, optional: true
  belongs_to :assignee, class_name: 'User', optional: true

  scope :by_stage, ->(s) { where(stage: s) if s.present? }
  scope :ordered, -> { order(:position, created_at: :desc) }

  # Código de exibição (ex.: RO-00001).
  def codigo
    format('RO-%05d', id)
  end
end
