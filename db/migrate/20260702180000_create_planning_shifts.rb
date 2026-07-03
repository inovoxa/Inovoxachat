# Planejamento — turnos alocados a recursos (agentes). Estilo Odoo Planning. Reversível.
class CreatePlanningShifts < ActiveRecord::Migration[7.1]
  def change
    create_table :planning_shifts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :company, foreign_key: true
      t.bigint :resource_id # agente (user); nulo = turno aberto
      t.datetime :start_at, null: false
      t.datetime :end_at
      t.string :role
      t.integer :status, null: false, default: 0
      t.text :notes
      t.timestamps
    end

    add_index :planning_shifts, [:account_id, :start_at]
    add_index :planning_shifts, :resource_id
  end
end
