# Cliente REST mínimo da Google Calendar API v3 (sem SDK, coerente com o
# padrão OAuth2 puro dos canais de e-mail do projeto).
class Calendar::Google::Client
  include HTTParty
  base_uri 'https://www.googleapis.com/calendar/v3'

  def initialize(connection)
    @connection = connection
  end

  # ID da agenda alvo (ex.: 'abc...@group.calendar.google.com'); vazio = principal.
  # URL-encoded porque o id contém '@' e vai no path.
  def calendar_id
    ERB::Util.url_encode(@connection.external_calendar_id.presence || 'primary')
  end

  # events.list — incremental via syncToken; primeira carga via timeMin.
  def list_events(sync_token: nil, page_token: nil, time_min: nil)
    query = { maxResults: 250, showDeleted: true }
    query[:syncToken] = sync_token if sync_token.present?
    query[:pageToken] = page_token if page_token.present?
    query[:timeMin] = time_min if time_min.present? && sync_token.blank?
    request(:get, "/calendars/#{calendar_id}/events", query: query)
  end

  def insert_event(payload)
    request(:post, "/calendars/#{calendar_id}/events", body: payload)
  end

  def patch_event(event_id, payload)
    request(:patch, "/calendars/#{calendar_id}/events/#{event_id}", body: payload)
  end

  # Push notifications: registra um canal apontando para o webhook público.
  def watch(channel_id:, token:, address:, expiration_ms: nil)
    body = { id: channel_id, type: 'web_hook', address: address, token: token }
    body[:expiration] = expiration_ms if expiration_ms
    request(:post, "/calendars/#{calendar_id}/events/watch", body: body)
  end

  def stop_channel(channel_id:, resource_id:)
    request(:post, '/channels/stop', body: { id: channel_id, resourceId: resource_id })
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

    raise Calendar::ApiError.new("Google Calendar API #{response.code}: #{response.body.to_s.truncate(300)}",
                                 status: response.code)
  end
end
