class CreateCalendarEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :calendar_events do |t|
      t.references :account, null: false, index: true
      # Agente dono/responsável pelo evento.
      t.references :user, null: false, index: true
      # Vínculos opcionais com o restante do produto.
      t.references :conversation, null: true, index: true
      t.references :contact, null: true, index: true
      t.references :pipeline_stage, null: true, index: true

      t.string :title, null: false
      t.text :description
      t.string :location
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.boolean :all_day, null: false, default: false
      t.string :timezone, null: false, default: 'UTC'
      # 0=confirmed | 1=tentative | 2=cancelled (ver enum em CalendarEvent)
      t.integer :status, null: false, default: 0
      # Regra de recorrência no formato RRULE do iCal (ex: FREQ=WEEKLY;BYDAY=MO,WE).
      t.string :recurrence_rule
      # 0=internal | 1=google | 2=outlook (origem do evento).
      t.integer :source, null: false, default: 0
      # Id do evento no provedor externo (Google/Graph), quando espelhado.
      t.string :external_event_id

      t.timestamps
    end

    add_index :calendar_events, :start_time
    add_index :calendar_events, [:account_id, :start_time]
    add_index :calendar_events, [:account_id, :external_event_id],
              unique: true,
              where: 'external_event_id IS NOT NULL',
              name: 'uniq_calendar_events_external_id'
  end
end
