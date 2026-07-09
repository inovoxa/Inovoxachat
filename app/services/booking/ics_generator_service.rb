# Gera uma string iCalendar (VCALENDAR/VEVENT) para um único evento de
# agendamento. Simples o suficiente para não exigir a gem `icalendar`.
class Booking::IcsGeneratorService
  def initialize(calendar_event, organizer_email: nil)
    @event = calendar_event
    @organizer_email = organizer_email
  end

  def generate
    lines = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Chatwoot//Booking//PT',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      "UID:#{uid}",
      "DTSTAMP:#{format_time(Time.current)}",
      "DTSTART:#{format_time(@event.start_time)}",
      "DTEND:#{format_time(@event.end_time)}",
      "SUMMARY:#{escape(@event.title)}"
    ]
    lines << "DESCRIPTION:#{escape(@event.description)}" if @event.description.present?
    lines << "LOCATION:#{escape(@event.location)}" if @event.location.present?
    lines << "ORGANIZER:mailto:#{@organizer_email}" if @organizer_email.present?
    lines += ['END:VEVENT', 'END:VCALENDAR']
    lines.join("\r\n")
  end

  private

  def uid
    "booking-#{@event.id}-#{@event.created_at.to_i}@chatwoot"
  end

  def format_time(time)
    time.utc.strftime('%Y%m%dT%H%M%SZ')
  end

  # Escapa os caracteres especiais do formato iCal (RFC 5545).
  def escape(value)
    value.to_s.gsub('\\', '\\\\\\\\').gsub("\n", '\\n').gsub(',', '\\,').gsub(';', '\\;')
  end
end
