class Api::V1::Accounts::CalendarEventsController < Api::V1::Accounts::BaseController
  before_action :fetch_calendar_event, only: [:show, :update, :destroy]
  before_action :authorize_event

  # Intervalo máximo consultado de uma vez — protege a expansão de recorrência
  # de RRULEs longas (ver Calendar::OccurrenceExpansionService).
  MAX_RANGE_DAYS = 90

  def index
    range_start, range_end = parse_range
    return render_invalid_range if range_start.nil?

    events = scoped_events(range_start, range_end)
    @occurrences = expand_occurrences(events, range_start, range_end)
  end

  def show; end

  def create
    @calendar_event = Current.account.calendar_events.new(event_params)
    @calendar_event.user ||= Current.user
    @calendar_event.save!
  end

  def update
    @calendar_event.update!(event_params)
  end

  def destroy
    @calendar_event.destroy!
    head :ok
  end

  private

  def fetch_calendar_event
    @calendar_event = Current.account.calendar_events.find(params[:id])
  end

  def authorize_event
    authorize(@calendar_event || CalendarEvent)
  end

  # Eventos simples no intervalo + os recorrentes (que serão expandidos depois),
  # aplicando os filtros opcionais.
  def scoped_events(range_start, range_end)
    scope = Current.account.calendar_events
                   .includes(:attendees, :conversation, :contact, pipeline_stage: :pipeline)
    scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
    scope = scope.where(conversation_id: params[:conversation_id]) if params[:conversation_id].present?
    scope = scope.where(contact_id: params[:contact_id]) if params[:contact_id].present?
    if params[:pipeline_id].present?
      scope = scope.joins(:pipeline_stage).where(pipeline_stages: { pipeline_id: params[:pipeline_id] })
    end

    non_recurring = scope.where(recurrence_rule: nil).in_range(range_start, range_end)
    recurring = scope.recurring
    non_recurring + recurring
  end

  # Cada evento vira uma ou mais ocorrências (hash) dentro do intervalo. Anexa o
  # próprio registro para o jbuilder acessar attendees/vínculos.
  def expand_occurrences(events, range_start, range_end)
    events.flat_map do |event|
      Calendar::OccurrenceExpansionService.new(event, range_start, range_end).expand
    end
  end

  def parse_range
    range_start = params[:start_date].present? ? Time.zone.parse(params[:start_date].to_s) : Time.current.beginning_of_month
    range_end = params[:end_date].present? ? Time.zone.parse(params[:end_date].to_s) : Time.current.end_of_month
    return [nil, nil] if range_start.nil? || range_end.nil?
    return [nil, nil] if range_end <= range_start
    return [nil, nil] if (range_end - range_start) > MAX_RANGE_DAYS.days

    [range_start, range_end]
  rescue ArgumentError
    [nil, nil]
  end

  def render_invalid_range
    render json: { error: "start_date/end_date invalidos ou intervalo maior que #{MAX_RANGE_DAYS} dias" },
           status: :unprocessable_entity
  end

  def event_params
    params.require(:calendar_event).permit(
      :title, :description, :location, :start_time, :end_time, :all_day, :timezone,
      :status, :recurrence_rule, :source, :conversation_id, :contact_id, :pipeline_stage_id, :user_id,
      attendees_attributes: [:id, :user_id, :email, :name, :response_status, :_destroy]
    )
  end
end
