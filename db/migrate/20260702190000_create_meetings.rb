# Calendário — reuniões (estilo Odoo Calendar). Participantes como lista de user ids. Reversível.
class CreateMeetings < ActiveRecord::Migration[7.1]
  def change
    create_table :meetings do |t|
      t.references :account, null: false, foreign_key: true
      t.references :company, foreign_key: true
      t.bigint :organizer_id
      t.string :title, null: false
      t.datetime :start_at, null: false
      t.datetime :end_at
      t.string :location
      t.text :description
      t.jsonb :participant_ids, default: []
      t.timestamps
    end

    add_index :meetings, [:account_id, :start_at]
  end
end
