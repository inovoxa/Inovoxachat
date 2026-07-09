# Cron (horário): renova webhooks que expiram em menos de 24h (Google ~7 dias,
# Graph ~3 dias) e registra os que ainda não existem.
class Calendar::TriggerWebhookRenewalJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    CalendarConnection.sync_enabled
                      .where('webhook_expires_at IS NULL OR webhook_expires_at < ?', 24.hours.from_now)
                      .find_each do |connection|
      Calendar::RegisterWebhookJob.perform_later(connection.id)
    end
  end
end
