# Expande um CalendarEvent recorrente em ocorrências virtuais (não persistidas)
# dentro de um intervalo. Usado pelo index do calendário e pelo cálculo de slots.
#
# Cada ocorrência é um Hash com os mesmos atributos do evento-pai, com
# start_time/end_time deslocados (a duração do pai é preservada) e marcadores
# `occurrence: true` + `occurrence_id`. O `id` continua sendo o do pai — a UI
# usa `occurrence_id` como chave de render e `id` para abrir/editar a série.
#
# MVP: edição sempre da série inteira; não há exceções por ocorrência (EXDATE).
class Calendar::OccurrenceExpansionService
  # Trava de segurança contra RRULEs sem UNTIL/COUNT (ex.: FREQ=DAILY infinito).
  MAX_OCCURRENCES = 100

  def initialize(event, range_start, range_end)
    @event = event
    @range_start = range_start
    @range_end = range_end
  end

  # Retorna array de hashes de ocorrência. Para eventos não recorrentes, devolve
  # um único hash representando o próprio evento (se estiver dentro do intervalo).
  def expand
    return [single_occurrence(@event.start_time, @event.end_time)] unless @event.recurring?

    duration = @event.end_time - @event.start_time
    occurrences_start_times.map do |occ_start|
      single_occurrence(occ_start, occ_start + duration)
    end
  end

  private

  def occurrences_start_times
    schedule.occurrences_between(@range_start, @range_end).first(MAX_OCCURRENCES)
  rescue StandardError => e
    Rails.logger.warn("[CalendarOccurrence] falha ao expandir event=#{@event.id}: #{e.message}")
    []
  end

  # Constrói o schedule no timezone do evento para que regras com BYDAY/BYMONTHDAY
  # respeitem o horário local mesmo através de mudanças de horário de verão.
  def schedule
    zone = ActiveSupport::TimeZone[@event.timezone] || Time.zone
    start = @event.start_time.in_time_zone(zone)
    IceCube::Schedule.new(start).tap do |s|
      s.add_recurrence_rule(IceCube::Rule.from_ical(@event.recurrence_rule))
    end
  end

  def single_occurrence(start_time, end_time)
    {
      id: @event.id,
      occurrence: @event.recurring?,
      occurrence_id: "#{@event.id}_#{start_time.to_i}",
      title: @event.title,
      description: @event.description,
      location: @event.location,
      start_time: start_time,
      end_time: end_time,
      all_day: @event.all_day,
      timezone: @event.timezone,
      status: @event.status,
      source: @event.source,
      recurrence_rule: @event.recurrence_rule,
      record: @event
    }
  end
end
