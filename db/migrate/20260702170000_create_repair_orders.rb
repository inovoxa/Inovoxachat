# Ordens de reparo (estilo Odoo Repair). Cliente (company) + equipamento opcionais. Reversível.
class CreateRepairOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :repair_orders do |t|
      t.references :account, null: false, foreign_key: true
      t.references :company, foreign_key: true
      t.references :equipment, foreign_key: true
      t.bigint :assignee_id
      t.integer :stage, null: false, default: 0
      t.datetime :scheduled_at
      t.boolean :in_warranty, null: false, default: false
      t.string :product_name
      t.text :notes
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :repair_orders, [:account_id, :stage]
    add_index :repair_orders, :assignee_id
  end
end
