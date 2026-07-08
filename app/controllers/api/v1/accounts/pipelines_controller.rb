class Api::V1::Accounts::PipelinesController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action :fetch_pipeline, except: [:index, :create, :templates]
  before_action :check_authorization

  # Presets de período do board (mesmo estilo dos filtros 7/30/90/180 dias).
  DEFAULT_CARDS_PERIOD_DAYS = 30

  def index
    scope = Current.account.pipelines.includes(:pipeline_stages, :inboxes)
    # Agente só enxerga funis vinculados a alguma inbox a que tem acesso.
    unless Current.account_user.administrator?
      scope = scope.joins(:pipeline_inboxes)
                   .where(pipeline_inboxes: { inbox_id: accessible_inbox_ids })
                   .distinct
    end
    @pipelines = scope
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
    @inbox_ids = visible_inbox_ids
  end

  private

  # Inboxes cujos cards devem aparecer no board:
  # - admin: todas as inboxes do funil (vazio = todas, funil global);
  # - agente: interseção entre as inboxes do funil e as inboxes a que tem acesso.
  def visible_inbox_ids
    pipeline_inbox_ids = @pipeline.inbox_ids
    return pipeline_inbox_ids if Current.account_user.administrator?

    pipeline_inbox_ids.present? ? (pipeline_inbox_ids & accessible_inbox_ids) : accessible_inbox_ids
  end

  def accessible_inbox_ids
    @accessible_inbox_ids ||= Current.user.assigned_inboxes.pluck(:id)
  end

  def cards_period_days
    days = params[:days].to_i
    days.positive? ? days : DEFAULT_CARDS_PERIOD_DAYS
  end

  def fetch_pipeline
    @pipeline = Current.account.pipelines.find(params[:id])
  end

  def permitted_params
    params.require(:pipeline).permit(:name, :description, :template_key, :auto_add_mode, inbox_ids: [])
  end
end
