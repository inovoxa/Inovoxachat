class CreateBookingRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :booking_requests do |t|
      t.references :booking_page, null: false, index: true
      # Preenchido após a confirmação (no MVP a confirmação é imediata).
      t.references :calendar_event, null: true, index: true

      t.string :guest_name, null: false
      t.string :guest_email, null: false
      t.string :guest_phone
      t.text :notes
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      # 0=pending | 1=confirmed | 2=cancelled (ver enum em BookingRequest)
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :booking_requests, :guest_email
    add_index :booking_requests, [:booking_page_id, :start_time]
  end
end
