class CreateCalendarConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :calendar_connections do |t|
      t.references :account, null: false, index: true
      t.references :user, null: false, index: true
      # 0=google | 1=outlook (ver enum em CalendarConnection)
      t.integer :provider, null: false
      # Tokens cifrados via Rails encrypts (quando ACTIVE_RECORD_ENCRYPTION_* configurado).
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at
      # Calendário alvo no provedor ('primary' no Google; id do calendário no Graph).
      t.string :external_calendar_id
      # nextSyncToken (Google) ou deltaLink (Graph) para sync incremental.
      t.text :sync_token
      # Webhook: canal Google (channel_id + resource_id p/ channels.stop) ou
      # subscription Graph (subscription_id). verification_token valida a origem.
      t.string :webhook_channel_id
      t.string :webhook_resource_id
      t.string :webhook_subscription_id
      t.string :webhook_verification_token
      t.datetime :webhook_expires_at
      t.boolean :sync_enabled, null: false, default: true
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :calendar_connections, [:user_id, :provider], unique: true
    add_index :calendar_connections, :webhook_channel_id
    add_index :calendar_connections, :webhook_subscription_id
  end
end
