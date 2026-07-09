class CreateBookingPages < ActiveRecord::Migration[7.1]
  def change
    create_table :booking_pages do |t|
      t.references :account, null: false, index: true
      # Agente dono da agenda pública.
      t.references :user, null: false, index: true
      # Inbox onde as conversas geradas pelo agendamento serão criadas.
      t.references :inbox, null: false, index: true
      # Estágio inicial do funil aplicado ao evento gerado (direção BookingPage->PipelineStage).
      t.references :default_pipeline_stage, null: true, index: true

      t.string :slug, null: false
      t.string :name, null: false
      t.text :description
      t.integer :duration_minutes, null: false, default: 30
      t.integer :buffer_before_minutes, null: false, default: 0
      t.integer :buffer_after_minutes, null: false, default: 0
      t.integer :min_notice_hours, null: false, default: 4
      t.integer :max_advance_days, null: false, default: 30
      t.string :timezone, null: false, default: 'UTC'
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :booking_pages, :slug, unique: true
  end
end
