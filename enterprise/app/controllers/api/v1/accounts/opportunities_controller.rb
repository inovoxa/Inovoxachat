class Api::V1::Accounts::OpportunitiesController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_companies_enabled!
  before_action :fetch_opportunity, only: [:show, :update, :destroy, :move, :ganhar, :perder]

  def index
    @opportunities = Current.account.opportunities
                            .includes(:company, :contact, :agent)
                            .by_stage(params[:stage])
                            .ordered
  end

  def show; end

  def create
    @opportunity = Current.account.opportunities.create!(opportunity_params)
    render :show
  end

  def update
    @opportunity.update!(opportunity_params)
    render :show
  end

  # PATCH move — arrastar card do funil (muda estágio/posição).
  def move
    @opportunity.update!(stage: params[:stage], position: params[:position] || 0)
    render :show
  end

  # POST ganhar — marca ganho e (por padrão) gera um contrato para a empresa.
  def ganhar
    @opportunity.ganhar!(gerar_contrato: params[:gerar_contrato].to_s != 'false')
    render :show
  end

  def perder
    @opportunity.perder!
    render :show
  end

  def destroy
    @opportunity.destroy!
    head :ok
  end

  private

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def fetch_opportunity
    @opportunity = Current.account.opportunities.find(params[:id])
  end

  def opportunity_params
    params.require(:opportunity).permit(
      :name, :company_id, :contact_id, :agent_id, :expected_value,
      :probability, :stage, :rating, :notes, :expected_closing
    )
  end
end
