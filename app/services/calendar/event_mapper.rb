# Converte CalendarEvent <-> payloads da Google Calendar API e do Microsoft Graph.
#
# Marcador anti-loop: eventos criados pelo Chatwoot levam o próprio id em
# extendedProperties.private.chatwoot_id (Google) / singleValueExtendedProperties
# (Graph). No pull, itens com esse marcador são reconhecidos como espelhos e não
# geram duplicata.
#
# Recorrência: o Graph não usa RRULE — convertemos apenas daily/weekly/monthly
# simples nos dois sentidos; padrões mais complexos ficam sem recurrence_rule
# local (o evento externo é read-only na UI de qualquer forma).
class Calendar::EventMapper
  # GUID fixo do conjunto de propriedades estendidas do Chatwoot no Graph.
  GRAPH_PROPERTY_ID = 'String {66f5a359-4659-4830-9070-00050ec6ac6e} Name chatwootId'.freeze

  GRAPH_DAYS = { 'MO' => 'monday', 'TU' => 'tuesday', 'WE' => 'wednesday', 'TH' => 'thursday',
                 'FR' => 'friday', 'SA' => 'saturday', 'SU' => 'sunday' }.freeze

  class << self
    # ---------- Google ----------

    def to_google(event)
      payload = {
        summary: event.title,
        description: event.description,
        location: event.location,
        start: google_time(event.start_time, event.all_day, event.timezone),
        end: google_time(event.end_time, event.all_day, event.timezone),
        status: event.cancelled? ? 'cancelled' : (event.tentative? ? 'tentative' : 'confirmed'),
        attendees: event.attendees.map { |a| { email: a.email, displayName: a.name }.compact },
        extendedProperties: { private: { chatwoot_id: event.id.to_s } }
      }
      payload[:recurrence] = ["RRULE:#{event.recurrence_rule}"] if event.recurrence_rule.present?
      payload.compact
    end

    # Retorna hash de atributos locais + metadados (:remote_updated, :chatwoot_id).
    def from_google(item)
      all_day = item.dig('start', 'date').present?
      {
        title: item['summary'].presence || '(sem título)',
        description: item['description'],
        location: item['location'],
        start_time: parse_google_time(item['start']),
        end_time: parse_google_time(item['end']),
        all_day: all_day,
        timezone: item.dig('start', 'timeZone') || 'UTC',
        status: google_status(item['status']),
        recurrence_rule: extract_rrule(item['recurrence']),
        remote_updated: item['updated'].present? ? Time.zone.parse(item['updated']) : nil,
        chatwoot_id: item.dig('extendedProperties', 'private', 'chatwoot_id')
      }
    end

    # ---------- Microsoft Graph ----------

    def to_graph(event)
      payload = {
        subject: event.title,
        body: { contentType: 'text', content: event.description.to_s },
        location: { displayName: event.location.to_s },
        start: graph_time(event.start_time, event.all_day, event.timezone),
        end: graph_time(event.end_time, event.all_day, event.timezone),
        isAllDay: event.all_day,
        showAs: event.tentative? ? 'tentative' : 'busy',
        attendees: event.attendees.map do |a|
          { emailAddress: { address: a.email, name: a.name }.compact, type: 'required' }
        end,
        singleValueExtendedProperties: [{ id: GRAPH_PROPERTY_ID, value: event.id.to_s }]
      }
      recurrence = graph_recurrence(event)
      payload[:recurrence] = recurrence if recurrence
      payload
    end

    def from_graph(item)
      {
        title: item['subject'].presence || '(sem título)',
        description: item.dig('body', 'content').to_s.strip.presence,
        location: item.dig('location', 'displayName').presence,
        start_time: parse_graph_time(item['start']),
        end_time: parse_graph_time(item['end']),
        all_day: item['isAllDay'] == true,
        timezone: item.dig('start', 'timeZone') || 'UTC',
        status: graph_status(item),
        recurrence_rule: rrule_from_graph(item['recurrence']),
        remote_updated: item['lastModifiedDateTime'].present? ? Time.zone.parse(item['lastModifiedDateTime']) : nil,
        chatwoot_id: graph_chatwoot_id(item)
      }
    end

    private

    # ---------- helpers Google ----------

    def google_time(time, all_day, timezone)
      return { date: time.to_date.iso8601 } if all_day

      { dateTime: time.utc.iso8601, timeZone: timezone.presence || 'UTC' }
    end

    def parse_google_time(block)
      return nil if block.blank?

      value = block['dateTime'] || block['date']
      value.present? ? Time.zone.parse(value) : nil
    end

    def google_status(status)
      case status
      when 'cancelled' then :cancelled
      when 'tentative' then :tentative
      else :confirmed
      end
    end

    def extract_rrule(recurrence)
      rule = Array(recurrence).find { |line| line.to_s.start_with?('RRULE:') }
      rule&.delete_prefix('RRULE:')
    end

    # ---------- helpers Graph ----------

    def graph_time(time, all_day, timezone)
      if all_day
        { dateTime: time.to_date.iso8601, timeZone: timezone.presence || 'UTC' }
      else
        { dateTime: time.utc.strftime('%Y-%m-%dT%H:%M:%S'), timeZone: 'UTC' }
      end
    end

    def parse_graph_time(block)
      return nil if block.blank?

      value = block['dateTime']
      return nil if value.blank?

      zone = ActiveSupport::TimeZone[block['timeZone'].to_s] || ActiveSupport::TimeZone['UTC']
      zone.parse(value)
    end

    def graph_status(item)
      return :cancelled if item['isCancelled'] == true

      item['showAs'] == 'tentative' ? :tentative : :confirmed
    end

    def graph_chatwoot_id(item)
      prop = Array(item['singleValueExtendedProperties']).find { |p| p['id'].to_s.include?('chatwootId') }
      prop&.dig('value')
    end

    # RRULE simples -> objeto recurrence do Graph (daily/weekly/monthly).
    def graph_recurrence(event)
      return nil if event.recurrence_rule.blank?

      parts = event.recurrence_rule.split(';').to_h { |kv| kv.split('=', 2) }
      start_date = event.start_time.to_date.iso8601
      range = { type: 'noEnd', startDate: start_date }

      case parts['FREQ']
      when 'DAILY'
        { pattern: { type: 'daily', interval: (parts['INTERVAL'] || 1).to_i }, range: range }
      when 'WEEKLY'
        days = (parts['BYDAY'] || '').split(',').filter_map { |d| GRAPH_DAYS[d] }
        days = [event.start_time.strftime('%A').downcase] if days.empty?
        { pattern: { type: 'weekly', interval: (parts['INTERVAL'] || 1).to_i, daysOfWeek: days }, range: range }
      when 'MONTHLY'
        { pattern: { type: 'absoluteMonthly', interval: (parts['INTERVAL'] || 1).to_i,
                     dayOfMonth: event.start_time.day }, range: range }
      end
    end

    # Objeto recurrence do Graph -> RRULE simples (padrões suportados; senão nil).
    def rrule_from_graph(recurrence)
      pattern = recurrence&.dig('pattern')
      return nil if pattern.blank?

      interval = pattern['interval'].to_i
      interval_part = interval > 1 ? ";INTERVAL=#{interval}" : ''

      case pattern['type']
      when 'daily'
        "FREQ=DAILY#{interval_part}"
      when 'weekly'
        days = Array(pattern['daysOfWeek']).filter_map { |d| GRAPH_DAYS.key(d.to_s.downcase) }
        by_day = days.any? ? ";BYDAY=#{days.join(',')}" : ''
        "FREQ=WEEKLY#{interval_part}#{by_day}"
      when 'absoluteMonthly'
        "FREQ=MONTHLY#{interval_part}"
      end
    end
  end
end
