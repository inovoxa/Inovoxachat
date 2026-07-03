class Api::V1::Accounts::RepairOrdersController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_companies_enabled!
  before_action :fetch_order, only: [:show, :update, :destroy, :move]

  def index
    @orders = Current.account.repair_orders
                     .by_stage(params[:stage])
                     .includes(:company, :equipment, :assignee)
                     .ordered
  end

  def show; end

  def create
    @order = Current.account.repair_orders.create!(order_params)
    render :show
  end

  def update
    @order.update!(order_params)
    render :show
  end

  def move
    @order.update!(stage: params[:stage], position: params[:position] || 0)
    render :show
  end

  def destroy
    @order.destroy!
    head :ok
  end

  private

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def fetch_order
    @order = Current.account.repair_orders.find(params[:id])
  end

  def order_params
    params.require(:repair_order).permit(
      :company_id, :equipment_id, :assignee_id, :stage, :scheduled_at,
      :in_warranty, :product_name, :notes, :position
    )
  end
end
