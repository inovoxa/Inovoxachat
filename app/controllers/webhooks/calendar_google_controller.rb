# Push notifications do Google Calendar. O Google envia apenas headers (sem
# corpo útil); a autenticidade é validada pelo par channel-id + channel-token
# gravado na conexão no momento do watch.
class Webhooks::CalendarGoogleController < ActionController::API
  def process_payload
    channel_id = request.headers['X-Goog-Channel-ID']
    token = request.headers['X-Goog-Channel-Token']
    connection = CalendarConnection.google.find_by(webhook_channel_id: channel_id)

    # 404 evita que um atacante descubra channel-ids válidos por diferença de resposta.
    return head :not_found if connection.nil? || !ActiveSupport::SecurityUtils.secure_compare(
      connection.webhook_verification_token.to_s, token.to_s
    )

    # A notificação 'sync' inicial também é aceita — dispara o primeiro pull.
    Calendar::HandleWebhookJob.perform_later('google', channel_id)
    head :ok
  end
end
