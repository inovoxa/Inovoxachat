# Processa uma notificação de webhook: resolve a conexão e dispara o sync.
# O payload dos provedores não traz o evento em si — apenas sinaliza mudança.
class Calendar::HandleWebhookJob < ApplicationJob
  queue_as :default

  def perform(provider, identifier)
    connection = case provider.to_s
                 when 'google'
                   CalendarConnection.google.find_by(webhook_channel_id: identifier)
                 when 'outlook'
                   CalendarConnection.outlook.find_by(webhook_subscription_id: identifier)
                 end
    return if connection.nil?

    Calendar::SyncEventsJob.perform_later(connection.id)
  end
end
