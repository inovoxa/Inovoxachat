# CRM — funil de vendas. Oportunidade ligada a Empresa + Contato (Chatwoot). Reversível.
class CreateOpportunities < ActiveRecord::Migration[7.1]
  def change
    create_table :opportunities do |t|
      t.references :account, null: false, foreign_key: true
      t.references :company, foreign_key: true
      t.references :contact, foreign_key: true
      t.bigint :agent_id # vendedor (users)
      t.string :name, null: false
      t.decimal :expected_value, precision: 12, scale: 2, default: 0
      t.integer :probability, default: 0
      t.integer :stage, null: false, default: 0
      t.integer :rating, default: 0
      t.integer :position, default: 0
      t.text :notes
      t.date :expected_closing
      t.datetime :won_at
      t.datetime :lost_at
      t.timestamps
    end

    add_index :opportunities, [:account_id, :stage]
    add_index :opportunities, :agent_id
  end
end
