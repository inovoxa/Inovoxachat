require 'rails_helper'

RSpec.describe 'Pipelines API', type: :request do
  let!(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/{account.id}/pipelines' do
    let!(:pipeline) { create(:pipeline, account: account, template_key: 'suporte') }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/pipelines"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated agent' do
      it 'returns all pipelines with nested stages' do
        get "/api/v1/accounts/#{account.id}/pipelines",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include(pipeline.name)
        expect(response.body).to include('Em Atendimento')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/pipelines' do
    context 'when it is an agent' do
      it 'returns unauthorized' do
        expect do
          post "/api/v1/accounts/#{account.id}/pipelines",
               headers: agent.create_new_auth_token,
               params: { name: 'Vendas' },
               as: :json
        end.not_to change(Pipeline, :count)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an administrator' do
      it 'creates a pipeline from a template with its stages' do
        post "/api/v1/accounts/#{account.id}/pipelines",
             headers: admin.create_new_auth_token,
             params: { name: 'Funil', template_key: 'vendas', auto_add_mode: 'new_contacts' },
             as: :json

        expect(response).to have_http_status(:success)
        pipeline = account.pipelines.last
        expect(pipeline.template_key).to eq('vendas')
        expect(pipeline.auto_add_mode).to eq('new_contacts')
        expect(pipeline.pipeline_stages.count).to eq(5)
      end

      it 'creates a custom pipeline with a single starting stage' do
        post "/api/v1/accounts/#{account.id}/pipelines",
             headers: admin.create_new_auth_token,
             params: { name: 'Personalizado' },
             as: :json

        expect(response).to have_http_status(:success)
        expect(account.pipelines.last.pipeline_stages.count).to eq(1)
      end

      it 'rejects an unknown template_key' do
        post "/api/v1/accounts/#{account.id}/pipelines",
             headers: admin.create_new_auth_token,
             params: { name: 'Inválido', template_key: 'nao_existe' },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/pipelines/:id' do
    let!(:pipeline) { create(:pipeline, account: account) }

    it 'updates the pipeline as administrator' do
      patch "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}",
            headers: admin.create_new_auth_token,
            params: { name: 'Novo nome', auto_add_mode: 'new_conversations' },
            as: :json

      expect(response).to have_http_status(:success)
      expect(pipeline.reload.name).to eq('Novo nome')
      expect(pipeline.reload.auto_add_mode).to eq('new_conversations')
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/pipelines/:id' do
    let!(:pipeline) { create(:pipeline, account: account) }

    it 'deletes the pipeline as administrator' do
      expect do
        delete "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}",
               headers: admin.create_new_auth_token,
               as: :json
      end.to change(Pipeline, :count).by(-1)

      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/pipelines/templates' do
    it 'returns the predefined templates for administrators' do
      get "/api/v1/accounts/#{account.id}/pipelines/templates",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      payload = response.parsed_body['payload']
      expect(payload.pluck('key')).to contain_exactly('suporte', 'vendas', 'generico')
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/pipelines/:id/cards' do
    let!(:pipeline) { create(:pipeline, account: account, template_key: 'suporte') }
    let(:stage) { pipeline.pipeline_stages.first }

    it 'returns the conversations of each stage within the period' do
      conversation = create(:conversation, account: account)
      conversation.update!(pipeline_stage: stage)

      get "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/cards",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      first_stage = response.parsed_body['payload'].first
      expect(first_stage['total_count']).to eq(1)
      expect(first_stage['conversations'].first['id']).to eq(conversation.display_id)
    end

    it 'filters out conversations older than the period' do
      conversation = create(:conversation, account: account)
      conversation.update_columns(pipeline_stage_id: stage.id, last_activity_at: 40.days.ago)

      get "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/cards",
          headers: agent.create_new_auth_token,
          params: { days: 30 },
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].first['total_count']).to eq(0)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/assign_pipeline_stage' do
    let!(:pipeline) { create(:pipeline, account: account, template_key: 'suporte') }
    let(:stage) { pipeline.pipeline_stages.first }
    let(:conversation) { create(:conversation, account: account) }

    it 'moves the conversation to the stage' do
      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/assign_pipeline_stage",
           headers: agent.create_new_auth_token,
           params: { pipeline_stage_id: stage.id },
           as: :json

      expect(response).to have_http_status(:success)
      expect(conversation.reload.pipeline_stage_id).to eq(stage.id)
    end

    it 'resolves the conversation when the target stage is mapped to resolved' do
      stage.update!(mapped_status: 'resolved')

      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/assign_pipeline_stage",
           headers: agent.create_new_auth_token,
           params: { pipeline_stage_id: stage.id },
           as: :json

      expect(response).to have_http_status(:success)
      expect(conversation.reload.status).to eq('resolved')
      expect(conversation.pipeline_stage_id).to eq(stage.id)
    end

    it 'reopens a resolved conversation when the target stage is mapped to open' do
      stage.update!(mapped_status: 'open')
      conversation.update!(status: :resolved)

      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/assign_pipeline_stage",
           headers: agent.create_new_auth_token,
           params: { pipeline_stage_id: stage.id },
           as: :json

      expect(response).to have_http_status(:success)
      expect(conversation.reload.status).to eq('open')
      expect(conversation.pipeline_stage_id).to eq(stage.id)
    end

    it 'keeps the conversation status when the target stage has no mapped status' do
      conversation.update!(status: :resolved)

      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/assign_pipeline_stage",
           headers: agent.create_new_auth_token,
           params: { pipeline_stage_id: stage.id },
           as: :json

      expect(response).to have_http_status(:success)
      expect(conversation.reload.status).to eq('resolved')
      expect(conversation.pipeline_stage_id).to eq(stage.id)
    end

    it 'clears the stage when pipeline_stage_id is blank' do
      conversation.update!(pipeline_stage: stage)

      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/assign_pipeline_stage",
           headers: agent.create_new_auth_token,
           params: { pipeline_stage_id: nil },
           as: :json

      expect(response).to have_http_status(:success)
      expect(conversation.reload.pipeline_stage_id).to be_nil
    end

    it 'rejects a stage from another account' do
      other_stage = create(:pipeline, template_key: 'vendas').pipeline_stages.first

      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/assign_pipeline_stage",
           headers: agent.create_new_auth_token,
           params: { pipeline_stage_id: other_stage.id },
           as: :json

      expect(response).to have_http_status(:not_found)
      expect(conversation.reload.pipeline_stage_id).to be_nil
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/contacts/:id/assign_pipeline_stage' do
    let!(:pipeline) { create(:pipeline, account: account, template_key: 'vendas') }
    let(:stage) { pipeline.pipeline_stages.first }
    let(:contact) { create(:contact, account: account) }

    it 'moves the contact to the stage' do
      post "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/assign_pipeline_stage",
           headers: agent.create_new_auth_token,
           params: { pipeline_stage_id: stage.id },
           as: :json

      expect(response).to have_http_status(:success)
      expect(contact.reload.pipeline_stage_id).to eq(stage.id)
    end
  end
end
