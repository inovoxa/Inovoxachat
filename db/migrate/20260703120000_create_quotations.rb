# Cotações de venda/locação (módulo Empresas, inspirado no Odoo Vendas). Reversível.
class CreateQuotations < ActiveRecord::Migration[7.1]
  def change
    create_table :quotations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :company, foreign_key: true
      t.references :contact, foreign_key: true
      t.bigint :agent_id
      t.bigint :opportunity_id
      t.string :number
      t.integer :status, null: false, default: 0
      t.date :expiration_date
      t.integer :recurring_plan, null: false, default: 0
      t.date :recurring_until
      t.string :payment_terms
      t.date :delivery_date
      t.decimal :amount_total, precision: 12, scale: 2, default: 0
      t.text :notes
      t.timestamps
    end

    add_index :quotations, [:account_id, :status]
    add_index :quotations, [:account_id, :number]
    add_index :quotations, :agent_id
    add_index :quotations, :opportunity_id
  end
end
