class Api::V1::Accounts::EquipmentsController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_companies_enabled!
  before_action :fetch_equipment, only: [:show, :update, :destroy]

  def index
    @equipments = Current.account.equipments.by_status(params[:status]).ordered_by_name
  end

  def show; end

  def create
    @equipment = Current.account.equipments.create!(equipment_params)
    render :show
  end

  def update
    @equipment.update!(equipment_params)
    render :show
  end

  def destroy
    @equipment.destroy!
    head :ok
  end

  private

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def fetch_equipment
    @equipment = Current.account.equipments.find(params[:id])
  end

  def equipment_params
    params.require(:equipment).permit(:name, :serial, :status)
  end
end
