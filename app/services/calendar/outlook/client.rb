# Cliente REST mínimo do Microsoft Graph v1.0 para calendário do usuário.
class Calendar::Outlook::Client
  include HTTParty
  base_uri 'https://graph.microsoft.com/v1.0'

  def initialize(connection)
    @connection = connection
  end

  # calendarView/delta — primeira carga com janela [start, end]; depois via deltaLink.
  def delta_start(start_time, end_time)
    request(:get, '/me/calendarView/delta', query: { startDateTime: start_time, endDateTime: end_time })
  end

  # nextLink/deltaLink são URLs absolutas devolvidas pelo Graph.
  def delta(url)
    response = HTTParty.get(url, headers: headers)
    handle(response)
  end

  def create_event(payload)
    request(:post, '/me/events', body: payload)
  end

  def update_event(event_id, payload)
    request(:patch, "/me/events/#{event_id}", body: payload)
  end

  def delete_event(event_id)
    request(:delete, "/me/events/#{event_id}")
  end

  def create_subscription(notification_url:, client_state:, expires_at:)
    request(:post, '/subscriptions', body: {
              changeType: 'created,updated,deleted',
              notificationUrl: notification_url,
              resource: '/me/events',
              expirationDateTime: expires_at.utc.iso8601,
              clientState: client_state
            })
  end

  def renew_subscription(subscription_id, expires_at:)
    request(:patch, "/subscriptions/#{subscription_id}", body: { expirationDateTime: expires_at.utc.iso8601 })
  end

  def delete_subscription(subscription_id)
    request(:delete, "/subscriptions/#{subscription_id}")
  end

  private

  def request(method, path, query: nil, body: nil)
    options = { headers: headers }
    options[:query] = query if query
    options[:body] = body.to_json if body
    response = self.class.public_send(method, path, options)
    handle(response)
  end

  def headers
    {
      'Authorization' => "Bearer #{Calendar::RefreshTokenService.new(@connection).access_token}",
      'Content-Type' => 'application/json'
    }
  end

  def handle(response)
    return response.parsed_response || {} if response.success?

    raise Calendar::ApiError.new("Microsoft Graph #{response.code}: #{response.body.to_s.truncate(300)}",
                                 status: response.code)
  end
end
