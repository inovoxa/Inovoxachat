# Itens de contrato: liga um contrato aos equipamentos alugados (módulo Empresas). Reversível.
class CreateContractItems < ActiveRecord::Migration[7.1]
  def change
    create_table :contract_items do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contract, null: false, foreign_key: true
      t.references :equipment, null: false, foreign_key: true
      t.integer :qty, null: false, default: 1
      t.date :return_date
      t.timestamps
    end
  end
end
