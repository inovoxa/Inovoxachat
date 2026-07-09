# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Calendar OAuth Config API', type: :request do
  let!(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/{account.id}/calendar/oauth_config' do
    it 'forbids agents' do
      get "/api/v1/accounts/#{account.id}/calendar/oauth_config",
          headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns client ids and secret presence, never the secret itself' do
      create(:installation_config, name: 'GOOGLE_CALENDAR_CLIENT_ID', value: 'the-client-id')
      create(:installation_config, name: 'GOOGLE_CALENDAR_CLIENT_SECRET', value: 'super-secret')

      get "/api/v1/accounts/#{account.id}/calendar/oauth_config",
          headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['google']['client_id']).to eq('the-client-id')
      expect(body['google']['secret_present']).to be(true)
      expect(response.body).not_to include('super-secret')
    end
  end

  describe 'PUT /api/v1/accounts/{account.id}/calendar/oauth_config' do
    it 'saves credentials and keeps the stored secret when the field comes blank' do
      put "/api/v1/accounts/#{account.id}/calendar/oauth_config",
          headers: admin.create_new_auth_token,
          params: { google: { client_id: 'id-1', client_secret: 'sec-1' } }, as: :json

      expect(response).to have_http_status(:success)
      expect(GlobalConfigService.load('GOOGLE_CALENDAR_CLIENT_SECRET', nil)).to eq('sec-1')

      # Segunda gravação sem secret não pode apagar o salvo.
      put "/api/v1/accounts/#{account.id}/calendar/oauth_config",
          headers: admin.create_new_auth_token,
          params: { google: { client_id: 'id-2', client_secret: '' } }, as: :json

      expect(GlobalConfigService.load('GOOGLE_CALENDAR_CLIENT_ID', nil)).to eq('id-2')
      expect(GlobalConfigService.load('GOOGLE_CALENDAR_CLIENT_SECRET', nil)).to eq('sec-1')
    end
  end
end
