class Api::V1::Accounts::ProjectTasksController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_companies_enabled!
  before_action :fetch_task, only: [:show, :update, :destroy, :move]

  # GET /project_tasks?project_id=
  def index
    @tasks = Current.account.project_tasks
                    .where(project_id: params[:project_id])
                    .includes(:assignee)
                    .ordered
  end

  def show; end

  def create
    @task = Current.account.project_tasks.create!(task_params)
    render :show
  end

  def update
    @task.update!(task_params)
    render :show
  end

  # PATCH move — arrastar card do Kanban (muda estágio/posição).
  def move
    @task.update!(stage: params[:stage], position: params[:position] || 0)
    render :show
  end

  def destroy
    @task.destroy!
    head :ok
  end

  private

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def fetch_task
    @task = Current.account.project_tasks.find(params[:id])
  end

  def task_params
    params.require(:project_task).permit(:project_id, :title, :stage, :assignee_id, :position)
  end
end
