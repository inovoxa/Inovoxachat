# Registra (ou renova) o webhook de push do provedor para uma conexão.
# Exige FRONTEND_URL público com HTTPS — sem isso o provedor rejeita o registro
# e o sync fica só no cron de 15 minutos.
class Calendar::RegisterWebhookJob < ApplicationJob
  queue_as :default

  def perform(connection_id)
    connection = CalendarConnection.find_by(id: connection_id)
    return if connection.nil? || !connection.sync_enabled

    service = connection.google? ? Calendar::Google::WebhookService : Calendar::Outlook::WebhookService
    service.new(connection).register
  rescue Calendar::ApiError => e
    Rails.logger.warn("[CalendarWebhook] registro falhou connection=#{connection_id}: #{e.message}")
  end
end
