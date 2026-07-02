class Api::V1::Accounts::ContractsController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_companies_enabled!
  before_action :fetch_contract, only: [:show, :update, :destroy]

  # GET /contracts?filter=a_vencer&days=30  |  ?filter=vencidos  |  ?status=ativo  |  ?company_id=
  def index
    @contracts = filtered_contracts.includes(:company, contract_items: :equipment)
                                   .order(end_date: :asc)
  end

  def show; end

  def create
    @contract = Current.account.contracts.create!(contract_params)
    render :show
  end

  def update
    @contract.update!(contract_params)
    render :show
  end

  def destroy
    @contract.destroy!
    head :ok
  end

  private

  def filtered_contracts
    scope = Current.account.contracts.for_company(params[:company_id])
    case params[:filter]
    when 'a_vencer' then scope.vencendo_em(params[:days].presence || 30)
    when 'vencidos' then scope.vencidos_por_data
    when 'ativos'   then scope.ativo
    else scope.by_status(params[:status])
    end
  end

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def fetch_contract
    @contract = Current.account.contracts.find(params[:id])
  end

  def contract_params
    params.require(:contract).permit(
      :company_id, :start_date, :end_date, :value, :status, :notes,
      contract_items_attributes: [:id, :equipment_id, :qty, :return_date, :_destroy]
    )
  end
end
