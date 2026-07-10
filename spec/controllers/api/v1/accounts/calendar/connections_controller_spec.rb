# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Calendar Connections API', type: :request do
  let!(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let!(:connection) do
    create(:calendar_connection, account: account, user: agent, sync_token: 'tok-1')
  end

  describe 'GET /api/v1/accounts/{account.id}/calendar/connections' do
    it 'lists only the current user connections' do
      create(:calendar_connection, account: account, user: other_agent)

      get "/api/v1/accounts/#{account.id}/calendar/connections",
          headers: agent.create_new_auth_token, as: :json

      payload = response.parsed_body['payload']
      expect(payload.length).to eq(1)
      expect(payload.first['id']).to eq(connection.id)
      expect(payload.first).to have_key('external_calendar_id')
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/calendar/connections/:id' do
    it 'toggles sync_enabled without touching the sync state' do
      patch "/api/v1/accounts/#{account.id}/calendar/connections/#{connection.id}",
            headers: agent.create_new_auth_token,
            params: { connection: { sync_enabled: false } }, as: :json

      expect(response).to have_http_status(:success)
      expect(connection.reload.sync_enabled).to be(false)
      expect(connection.sync_token).to eq('tok-1')
    end

    it 'changing the calendar id resets the sync token and restarts webhook + sync' do
      expect do
        patch "/api/v1/accounts/#{account.id}/calendar/connections/#{connection.id}",
              headers: agent.create_new_auth_token,
              params: { connection: { external_calendar_id: 'abc@group.calendar.google.com' } }, as: :json
      end.to have_enqueued_job(Calendar::RegisterWebhookJob).with(connection.id)
        .and have_enqueued_job(Calendar::SyncEventsJob).with(connection.id)

      connection.reload
      expect(connection.external_calendar_id).to eq('abc@group.calendar.google.com')
      expect(connection.sync_token).to be_nil
    end

    it 'keeps the sync state when the calendar id is unchanged' do
      connection.update!(external_calendar_id: 'same@group.calendar.google.com')
      connection.update!(sync_token: 'tok-2')

      expect do
        patch "/api/v1/accounts/#{account.id}/calendar/connections/#{connection.id}",
              headers: agent.create_new_auth_token,
              params: { connection: { external_calendar_id: 'same@group.calendar.google.com', sync_enabled: true } },
              as: :json
      end.not_to have_enqueued_job(Calendar::SyncEventsJob)

      expect(connection.reload.sync_token).to eq('tok-2')
    end

    it 'forbids updating another user connection' do
      patch "/api/v1/accounts/#{account.id}/calendar/connections/#{connection.id}",
            headers: other_agent.create_new_auth_token,
            params: { connection: { sync_enabled: false } }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
