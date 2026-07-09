# Calcula os horários livres de uma BookingPage para um dia específico.
#
# Todo o raciocínio acontece no fuso da página (Time.use_zone); os horários
# retornados são ISO8601 em UTC e o frontend converte para o fuso do visitante.
#
# Um slot é válido quando:
#   - está inteiramente contido numa faixa de disponibilidade do dia;
#   - respeita a antecedência mínima (min_notice_hours) e o horizonte máximo
#     (max_advance_days);
#   - não colide, considerando os buffers, com nenhum evento confirmado/provisório
#     do agente dono (internos + sincronizados + ocorrências de recorrentes).
class Booking::AvailableSlotsService
  def initialize(booking_page, date_string)
    @page = booking_page
    @date_string = date_string
  end

  def slots
    Time.use_zone(@page.timezone) do
      date = parse_date
      return [] if date.nil? || out_of_horizon?(date)

      candidate_slots(date).reject { |slot| too_soon?(slot[:start]) || conflicts?(slot) }
                           .map { |slot| { start_time: slot[:start].utc.iso8601, end_time: slot[:end].utc.iso8601 } }
    end
  end

  private

  def parse_date
    Date.parse(@date_string.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def out_of_horizon?(date)
    date < Time.zone.today || date > (Time.zone.today + @page.max_advance_days.days)
  end

  # Gera slots de `duration_minutes` em passos da mesma duração, contidos nas
  # faixas de disponibilidade do dia da semana.
  def candidate_slots(date)
    duration = @page.duration_minutes.minutes
    @page.availabilities.where(day_of_week: date.wday).flat_map do |availability|
      window_start = combine(date, availability.start_time)
      window_end = combine(date, availability.end_time)
      build_slots(window_start, window_end, duration)
    end
  end

  def build_slots(window_start, window_end, duration)
    slots = []
    cursor = window_start
    while cursor + duration <= window_end
      slots << { start: cursor, end: cursor + duration }
      cursor += duration
    end
    slots
  end

  def too_soon?(slot_start)
    slot_start < Time.current + @page.min_notice_hours.hours
  end

  # Colisão considerando os buffers antes/depois do slot.
  def conflicts?(slot)
    padded_start = slot[:start] - @page.buffer_before_minutes.minutes
    padded_end = slot[:end] + @page.buffer_after_minutes.minutes
    busy_intervals.any? { |busy| padded_start < busy[:end] && busy[:start] < padded_end }
  end

  # Intervalos ocupados do dono da página, com recorrentes já expandidos.
  def busy_intervals
    @busy_intervals ||= begin
      range_start = Time.zone.now.beginning_of_day
      range_end = (Time.zone.today + @page.max_advance_days.days).end_of_day
      events = @page.user.calendar_events
                    .where(status: %i[confirmed tentative])
                    .where('start_time < ? AND (end_time > ? OR recurrence_rule IS NOT NULL)', range_end, range_start)
      events.flat_map do |event|
        event.occurrences_between(range_start, range_end)
             .map { |occ| { start: occ[:start_time], end: occ[:end_time] } }
      end
    end
  end

  def combine(date, time_value)
    Time.zone.local(date.year, date.month, date.day, time_value.hour, time_value.min, 0)
  end
end
