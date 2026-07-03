class Api::V1::Accounts::PlanningShiftsController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_companies_enabled!
  before_action :fetch_shift, only: [:show, :update, :destroy]

  # GET /planning_shifts?date=YYYY-MM-DD  (padrão: hoje)
  def index
    date = (Date.parse(params[:date].to_s) rescue Date.current)
    @shifts = Current.account.planning_shifts.on_day(date).includes(:company, :resource).ordered
  end

  def show; end

  def create
    @shift = Current.account.planning_shifts.create!(shift_params)
    render :show
  end

  def update
    @shift.update!(shift_params)
    render :show
  end

  def destroy
    @shift.destroy!
    head :ok
  end

  private

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def fetch_shift
    @shift = Current.account.planning_shifts.find(params[:id])
  end

  def shift_params
    params.require(:planning_shift).permit(
      :company_id, :resource_id, :start_at, :end_at, :role, :status, :notes
    )
  end
end
