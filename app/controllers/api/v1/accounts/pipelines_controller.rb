class Api::V1::Accounts::PipelinesController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action :fetch_pipeline, except: [:index, :create, :templates]
  before_action :check_authorization

  # Presets de período do board (mesmo estilo dos filtros 7/30/90/180 dias).
  DEFAULT_CARDS_PERIOD_DAYS = 30

  def index
    @pipelines = policy_scope(Current.account.pipelines.includes(:pipeline_stages))
  end

  def show; end

  # Templates predefinidos para o modal de criação (com preview dos estágios).
  def templates; end

  def create
    @pipeline = Current.account.pipelines.create!(permitted_params)
  end

  def update
    @pipeline.update!(permitted_params)
  end

  def destroy
    @pipeline.destroy!
    head :ok
  end

  # Cards do board (conversas + contatos por estágio), filtrados por período.
  def cards
    @since = cards_period_days.days.ago
  end

  private

  def cards_period_days
    days = params[:days].to_i
    days.positive? ? days : DEFAULT_CARDS_PERIOD_DAYS
  end

  def fetch_pipeline
    @pipeline = Current.account.pipelines.find(params[:id])
  end

  def permitted_params
    params.require(:pipeline).permit(:name, :description, :template_key, :auto_add_mode)
  end
end
