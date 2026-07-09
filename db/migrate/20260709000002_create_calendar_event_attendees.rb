class CreateCalendarEventAttendees < ActiveRecord::Migration[7.1]
  def change
    create_table :calendar_event_attendees do |t|
      t.references :calendar_event, null: false, index: true
      # Preenchido quando o participante é um agente interno; nulo para convidados externos.
      t.references :user, null: true, index: true
      t.string :email, null: false
      t.string :name
      # 0=pending | 1=accepted | 2=declined (ver enum em CalendarEventAttendee)
      t.integer :response_status, null: false, default: 0

      t.timestamps
    end

    add_index :calendar_event_attendees, [:calendar_event_id, :email], unique: true
  end
end
