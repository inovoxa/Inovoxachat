# Equipamentos disponíveis para locação (módulo Empresas). Reversível.
class CreateEquipments < ActiveRecord::Migration[7.1]
  def change
    create_table :equipments do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :serial
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :equipments, [:account_id, :status]
    add_index :equipments, [:account_id, :serial], unique: true, where: 'serial IS NOT NULL',
                           name: 'index_equipments_on_account_and_serial'
  end
end
