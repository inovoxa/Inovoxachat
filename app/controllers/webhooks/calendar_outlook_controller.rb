# Notificações do Microsoft Graph. No handshake de criação da subscription o
# Graph manda ?validationToken= e espera o valor de volta em texto puro; nas
# notificações reais valida-se o clientState de cada item.
class Webhooks::CalendarOutlookController < ActionController::API
  def process_payload
    # Handshake de validação da subscription.
    if params[:validationToken].present?
      return render plain: params[:validationToken], content_type: 'text/plain', status: :ok
    end

    notifications = Array(params[:value])
    notifications.each do |notification|
      subscription_id = notification['subscriptionId']
      connection = CalendarConnection.outlook.find_by(webhook_subscription_id: subscription_id)
      next if connection.nil?
      next unless ActiveSupport::SecurityUtils.secure_compare(
        connection.webhook_verification_token.to_s, notification['clientState'].to_s
      )

      Calendar::HandleWebhookJob.perform_later('outlook', subscription_id)
    end

    # O Graph espera 202 para considerar a notificação entregue.
    head :accepted
  end
end
