# Cria/renova/apaga a subscription de mudanças do Graph (expira em ~3 dias).
class Calendar::Outlook::WebhookService
  # Máximo permitido pelo Graph para /me/events é 4230 minutos (~2,9 dias).
  MAX_TTL = 4200.minutes

  def initialize(connection)
    @connection = connection
  end

  def register
    return renew if @connection.webhook_subscription_id.present?

    token = SecureRandom.hex(24)
    response = client.create_subscription(
      notification_url: "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/calendar/outlook",
      client_state: token,
      expires_at: MAX_TTL.from_now
    )
    @connection.update!(
      webhook_subscription_id: response['id'],
      webhook_verification_token: token,
      webhook_expires_at: response['expirationDateTime'].present? ? Time.zone.parse(response['expirationDateTime']) : MAX_TTL.from_now
    )
  end

  def renew
    response = client.renew_subscription(@connection.webhook_subscription_id, expires_at: MAX_TTL.from_now)
    @connection.update!(
      webhook_expires_at: response['expirationDateTime'].present? ? Time.zone.parse(response['expirationDateTime']) : MAX_TTL.from_now
    )
  rescue Calendar::ApiError => e
    # Subscription perdida/expirada no provedor: recria do zero.
    raise unless [404, 410].include?(e.status)

    @connection.update!(webhook_subscription_id: nil)
    register
  end

  def unregister
    return if @connection.webhook_subscription_id.blank?

    client.delete_subscription(@connection.webhook_subscription_id)
  rescue Calendar::ApiError => e
    Rails.logger.warn("[CalendarWebhook] graph delete falhou connection=#{@connection.id}: #{e.message}")
  end

  private

  def client
    @client ||= Calendar::Outlook::Client.new(@connection)
  end
end
