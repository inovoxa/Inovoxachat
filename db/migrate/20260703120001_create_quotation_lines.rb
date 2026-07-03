# Linhas do pedido de uma cotação (produto/equipamento, qtd, preço, desconto, imposto). Reversível.
class CreateQuotationLines < ActiveRecord::Migration[7.1]
  def change
    create_table :quotation_lines do |t|
      t.references :account, null: false, foreign_key: true
      t.references :quotation, null: false, foreign_key: true
      t.references :equipment, foreign_key: true
      t.boolean :is_section, null: false, default: false
      t.string :name, null: false
      t.decimal :qty, precision: 12, scale: 2, default: 1
      t.decimal :unit_price, precision: 12, scale: 2, default: 0
      t.decimal :tax_percent, precision: 5, scale: 2, default: 0
      t.decimal :discount_percent, precision: 5, scale: 2, default: 0
      t.decimal :amount, precision: 12, scale: 2, default: 0
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :quotation_lines, [:quotation_id, :position]
  end
end
