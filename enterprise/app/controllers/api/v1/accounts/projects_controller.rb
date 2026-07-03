class Api::V1::Accounts::ProjectsController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_companies_enabled!
  before_action :fetch_project, only: [:show, :update, :destroy]

  def index
    @projects = Current.account.projects.by_status(params[:status]).ordered
  end

  def show; end

  def create
    @project = Current.account.projects.create!(project_params)
    render :show
  end

  def update
    @project.update!(project_params)
    render :show
  end

  def destroy
    @project.destroy!
    head :ok
  end

  private

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def fetch_project
    @project = Current.account.projects.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :description, :company_id, :status)
  end
end
