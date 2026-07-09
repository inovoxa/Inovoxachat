class Calendar::Outlook::SyncService < Calendar::BaseSyncService
  # Janela do calendarView na primeira carga.
  DELTA_PAST = 30.days
  DELTA_FUTURE = 180.days

  private

  def client
    @client ||= Calendar::Outlook::Client.new(@connection)
  end

  # calendarView/delta: primeira carga com janela; incrementos via deltaLink.
  # deltaLink inválido (410/gone) reseta para full sync.
  def pull(allow_retry: true)
    response = initial_or_delta_response

    loop do
      Array(response['value']).each { |item| apply_graph_item(item) }
      next_link = response['@odata.nextLink']
      if next_link.present?
        response = client.delta(next_link)
      else
        delta_link = response['@odata.deltaLink']
        @connection.update!(sync_token: delta_link) if delta_link.present?
        break
      end
    end
  rescue Calendar::ApiError => e
    raise unless [404, 410].include?(e.status) && allow_retry

    @connection.update!(sync_token: nil)
    pull(allow_retry: false)
  end

  def initial_or_delta_response
    if @connection.sync_token.present?
      client.delta(@connection.sync_token)
    else
      client.delta_start(DELTA_PAST.ago.utc.iso8601, DELTA_FUTURE.from_now.utc.iso8601)
    end
  end

  def apply_graph_item(item)
    # Remoção sinalizada pelo delta.
    if item['@removed'].present?
      event = @connection.account.calendar_events.find_by(external_event_id: item['id'])
      return apply_remote_cancellation(event)
    end

    # Só o mestre da série ou eventos avulsos; instâncias/exceções são ignoradas.
    return if %w[occurrence exception].include?(item['type'])

    attrs = Calendar::EventMapper.from_graph(item)
    apply_remote_attributes(item['id'], attrs, cancelled: item['isCancelled'] == true)
  rescue StandardError => e
    Rails.logger.error("[CalendarSync] graph item #{item['id']} falhou: #{e.message}")
  end

  def push_create(event)
    # Cancelado local ainda sem espelho não precisa ir ao provedor.
    return nil if event.cancelled?

    response = client.create_event(Calendar::EventMapper.to_graph(event))
    response['id']
  end

  def push_update(event)
    if event.cancelled?
      # O Graph não aceita PATCH de isCancelled — cancelamento vira DELETE lá,
      # mantendo o registro local como cancelled.
      begin
        client.delete_event(event.external_event_id)
      rescue Calendar::ApiError => e
        raise unless e.status == 404
      end
    else
      client.update_event(event.external_event_id, Calendar::EventMapper.to_graph(event))
    end
  end
end
