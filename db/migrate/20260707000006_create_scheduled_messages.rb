class CreateScheduledMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :scheduled_messages do |t|
      t.references :account, null: false, index: true
      t.references :conversation, null: false, index: true
      t.references :created_by, index: true
      t.text :content, null: false
      t.datetime :scheduled_at, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :scheduled_messages, [:status, :scheduled_at]
  end
end
