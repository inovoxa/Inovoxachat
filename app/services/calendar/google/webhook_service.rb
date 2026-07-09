# Registra/encerra o canal de push notifications do Google Calendar.
# Canais expiram (máx ~7 dias) — o TriggerWebhookRenewalJob renova com folga.
class Calendar::Google::WebhookService
  MAX_TTL = 6.days

  def initialize(connection)
    @connection = connection
  end

  def register
    stop_existing
    channel_id = SecureRandom.uuid
    token = SecureRandom.hex(24)
    response = client.watch(
      channel_id: channel_id,
      token: token,
      address: "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/calendar/google",
      expiration_ms: (MAX_TTL.from_now.to_f * 1000).to_i
    )
    @connection.update!(
      webhook_channel_id: channel_id,
      webhook_resource_id: response['resourceId'],
      webhook_verification_token: token,
      webhook_expires_at: response['expiration'].present? ? Time.at(response['expiration'].to_i / 1000).utc : MAX_TTL.from_now
    )
  end

  def stop_existing
    return if @connection.webhook_channel_id.blank? || @connection.webhook_resource_id.blank?

    client.stop_channel(channel_id: @connection.webhook_channel_id, resource_id: @connection.webhook_resource_id)
  rescue Calendar::ApiError => e
    Rails.logger.warn("[CalendarWebhook] google stop falhou connection=#{@connection.id}: #{e.message}")
  end

  private

  def client
    @client ||= Calendar::Google::Client.new(@connection)
  end
end
