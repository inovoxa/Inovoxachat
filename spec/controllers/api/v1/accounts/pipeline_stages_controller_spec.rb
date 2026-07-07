require 'rails_helper'

RSpec.describe 'Pipeline Stages API', type: :request do
  let!(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:pipeline) { create(:pipeline, account: account, template_key: 'generico') }

  describe 'GET /api/v1/accounts/{account.id}/pipelines/:pipeline_id/stages' do
    it 'returns the stages ordered by position for agents' do
      get "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/stages",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].pluck('name')).to eq(['Início', 'Em Progresso', 'Concluído'])
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/pipelines/:pipeline_id/stages' do
    context 'when it is an agent' do
      it 'returns unauthorized' do
        expect do
          post "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/stages",
               headers: agent.create_new_auth_token,
               params: { name: 'Extra' },
               as: :json
        end.not_to change(PipelineStage, :count)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an administrator' do
      it 'creates the stage at the end of the board' do
        post "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/stages",
             headers: admin.create_new_auth_token,
             params: { name: 'Extra', color: '#FF0000' },
             as: :json

        expect(response).to have_http_status(:success)
        stage = pipeline.pipeline_stages.reload.last
        expect(stage.name).to eq('Extra')
        expect(stage.position).to eq(4)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/pipelines/:pipeline_id/stages/:id' do
    it 'updates name and color as administrator' do
      stage = pipeline.pipeline_stages.first

      patch "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/stages/#{stage.id}",
            headers: admin.create_new_auth_token,
            params: { name: 'Backlog', color: '#000000' },
            as: :json

      expect(response).to have_http_status(:success)
      expect(stage.reload.name).to eq('Backlog')
      expect(stage.reload.color).to eq('#000000')
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/pipelines/:pipeline_id/stages/:id' do
    it 'deletes the stage as administrator' do
      stage = pipeline.pipeline_stages.first

      expect do
        delete "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/stages/#{stage.id}",
               headers: admin.create_new_auth_token,
               as: :json
      end.to change(PipelineStage, :count).by(-1)

      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/pipelines/:pipeline_id/stages/reorder' do
    it 'applies the new order as administrator' do
      original_ids = pipeline.pipeline_stages.map(&:id)

      post "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/stages/reorder",
           headers: admin.create_new_auth_token,
           params: { stage_ids: original_ids.reverse },
           as: :json

      expect(response).to have_http_status(:success)
      expect(pipeline.pipeline_stages.reload.map(&:id)).to eq(original_ids.reverse)
    end

    context 'when it is an agent' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/stages/reorder",
             headers: agent.create_new_auth_token,
             params: { stage_ids: pipeline.pipeline_stages.map(&:id) },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
