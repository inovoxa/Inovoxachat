class Calendar::Google::SyncService < Calendar::BaseSyncService
  private

  def client
    @client ||= Calendar::Google::Client.new(@connection)
  end

  # events.list incremental via syncToken; 410 GONE invalida o token e força
  # um full resync (o upsert por external_event_id evita duplicatas).
  def pull(allow_retry: true)
    page_token = nil
    new_sync_token = nil

    loop do
      response = client.list_events(
        sync_token: @connection.sync_token,
        page_token: page_token,
        time_min: @connection.sync_token.blank? ? 30.days.ago.utc.iso8601 : nil
      )
      Array(response['items']).each { |item| apply_google_item(item) }
      new_sync_token = response['nextSyncToken'] if response['nextSyncToken'].present?
      page_token = response['nextPageToken']
      break if page_token.blank?
    end

    @connection.update!(sync_token: new_sync_token) if new_sync_token.present?
  rescue Calendar::ApiError => e
    raise unless e.status == 410 && allow_retry

    @connection.update!(sync_token: nil)
    pull(allow_retry: false)
  end

  def apply_google_item(item)
    # Instâncias de série chegam com recurringEventId — só o mestre é sincronizado.
    return if item['recurringEventId'].present?

    attrs = Calendar::EventMapper.from_google(item)
    apply_remote_attributes(item['id'], attrs, cancelled: item['status'] == 'cancelled')
  rescue StandardError => e
    Rails.logger.error("[CalendarSync] google item #{item['id']} falhou: #{e.message}")
  end

  def push_create(event)
    response = client.insert_event(Calendar::EventMapper.to_google(event))
    response['id']
  end

  def push_update(event)
    client.patch_event(event.external_event_id, Calendar::EventMapper.to_google(event))
  end
end
