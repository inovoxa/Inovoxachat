require 'rails_helper'

RSpec.describe 'Scheduled Messages API', type: :request do
  let!(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe 'POST create' do
    it 'schedules a message for the conversation' do
      expect do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/scheduled_messages",
             headers: agent.create_new_auth_token,
             params: { scheduled_message: { content: 'Olá!', scheduled_at: 2.hours.from_now.iso8601 } },
             as: :json
      end.to change(ScheduledMessage, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(ScheduledMessage.last.created_by).to eq(agent)
    end
  end

  describe 'GET index' do
    it 'lists the scheduled messages of the conversation' do
      create(:scheduled_message, conversation: conversation, content: 'Agendada X')

      get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/scheduled_messages",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Agendada X')
    end
  end

  describe 'DELETE destroy' do
    it 'cancels a pending scheduled message' do
      scheduled = create(:scheduled_message, conversation: conversation)

      delete "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/scheduled_messages/#{scheduled.id}",
             headers: agent.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:success)
      expect(scheduled.reload.status).to eq('canceled')
    end
  end
end
