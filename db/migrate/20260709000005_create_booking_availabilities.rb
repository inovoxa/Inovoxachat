class CreateBookingAvailabilities < ActiveRecord::Migration[7.1]
  def change
    create_table :booking_availabilities do |t|
      t.references :booking_page, null: false, index: true
      # 0=domingo ... 6=sábado (mesma convenção de Date#wday).
      t.integer :day_of_week, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false

      t.timestamps
    end

    # Não é único: pode haver múltiplas faixas de horário no mesmo dia.
    add_index :booking_availabilities, [:booking_page_id, :day_of_week]
  end
end
