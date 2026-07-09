# Sincroniza uma conexão de calendário (pull + push). Enfileirado pelo cron
# (TriggerSyncJob), pelos webhooks (HandleWebhookJob) e ao conectar.
class Calendar::SyncEventsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform(connection_id)
    connection = CalendarConnection.find_by(id: connection_id)
    return if connection.nil? || !connection.sync_enabled

    service = connection.google? ? Calendar::Google::SyncService : Calendar::Outlook::SyncService
    service.new(connection).perform
  end
end
