class Api::V1::Accounts::MeetingsController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_companies_enabled!
  before_action :fetch_meeting, only: [:show, :update, :destroy]

  # GET /meetings?from=YYYY-MM-DD&to=YYYY-MM-DD (padrão: semana atual)
  def index
    from = (Time.zone.parse(params[:from].to_s) rescue Time.current.beginning_of_week(:sunday))
    to = (Time.zone.parse(params[:to].to_s) rescue from + 7.days)
    @meetings = Current.account.meetings.in_range(from, to).includes(:company, :organizer).ordered
  end

  def show; end

  def create
    @meeting = Current.account.meetings.create!(meeting_params)
    render :show
  end

  def update
    @meeting.update!(meeting_params)
    render :show
  end

  def destroy
    @meeting.destroy!
    head :ok
  end

  private

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def fetch_meeting
    @meeting = Current.account.meetings.find(params[:id])
  end

  def meeting_params
    params.require(:meeting).permit(
      :title, :company_id, :organizer_id, :start_at, :end_at, :location, :description,
      participant_ids: []
    )
  end
end
