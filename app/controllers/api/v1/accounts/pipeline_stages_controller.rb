class Api::V1::Accounts::PipelineStagesController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action :fetch_pipeline
  before_action :fetch_pipeline_stage, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @pipeline_stages = @pipeline.pipeline_stages
  end

  def create
    next_position = @pipeline.pipeline_stages.maximum(:position).to_i + 1
    @pipeline_stage = @pipeline.pipeline_stages.create!(permitted_params.reverse_merge(position: next_position))
  end

  def update
    @pipeline_stage.update!(permitted_params)
  end

  def destroy
    @pipeline_stage.destroy!
    head :ok
  end

  # Recebe { stage_ids: [...] } na nova ordem e reposiciona todos os estágios.
  def reorder
    stage_ids = params.require(:stage_ids)
    ActiveRecord::Base.transaction do
      stage_ids.each_with_index do |stage_id, index|
        @pipeline.pipeline_stages.find(stage_id).update!(position: index + 1)
      end
    end
    @pipeline_stages = @pipeline.pipeline_stages.reload
    render :index
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.pipelines.find(params[:pipeline_id])
  end

  def fetch_pipeline_stage
    @pipeline_stage = @pipeline.pipeline_stages.find(params[:id])
  end

  def permitted_params
    params.require(:pipeline_stage).permit(:name, :color, :position)
  end
end
