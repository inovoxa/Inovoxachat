# Cron (*/15min): enfileira um SyncEventsJob por conexão habilitada. É o
# fallback obrigatório quando o webhook não alcança a instância (ex.: dev).
class Calendar::TriggerSyncJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    CalendarConnection.sync_enabled.find_each do |connection|
      Calendar::SyncEventsJob.perform_later(connection.id)
    end
  end
end
