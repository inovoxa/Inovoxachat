# Módulo Projetos (estilo Odoo). Projeto opcionalmente ligado a uma empresa. Reversível.
class CreateProjects < ActiveRecord::Migration[7.1]
  def change
    create_table :projects do |t|
      t.references :account, null: false, foreign_key: true
      t.references :company, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :projects, [:account_id, :status]
  end
end
