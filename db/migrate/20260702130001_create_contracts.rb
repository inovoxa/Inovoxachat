# Contratos de locação por empresa (módulo Empresas). Reversível.
class CreateContracts < ActiveRecord::Migration[7.1]
  def change
    create_table :contracts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.date :start_date
      t.date :end_date
      t.decimal :value, precision: 12, scale: 2
      t.integer :status, null: false, default: 0
      t.text :notes
      t.timestamps
    end

    add_index :contracts, [:account_id, :status]
    add_index :contracts, [:account_id, :end_date]
  end
end
