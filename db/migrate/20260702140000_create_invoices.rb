# Faturas por empresa/contrato (módulo Empresas — financeiro). Reversível.
class CreateInvoices < ActiveRecord::Migration[7.1]
  def change
    create_table :invoices do |t|
      t.references :account, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.references :contract, foreign_key: true
      t.date :due_date, null: false
      t.decimal :amount, precision: 12, scale: 2
      t.datetime :paid_at
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :invoices, [:account_id, :status]
    add_index :invoices, [:account_id, :due_date]
  end
end
