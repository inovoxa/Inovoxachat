# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Calendar Webhooks', type: :request do
  describe 'POST /webhooks/calendar/google' do
    let!(:connection) { create(:calendar_connection, :with_webhook) }

    it 'enqueues a handle job for a valid channel + token' do
      expect do
        post '/webhooks/calendar/google', headers: {
          'X-Goog-Channel-ID' => connection.webhook_channel_id,
          'X-Goog-Channel-Token' => connection.webhook_verification_token
        }
      end.to have_enqueued_job(Calendar::HandleWebhookJob).with('google', connection.webhook_channel_id)

      expect(response).to have_http_status(:ok)
    end

    it 'rejects an unknown channel id' do
      post '/webhooks/calendar/google', headers: { 'X-Goog-Channel-ID' => 'nope', 'X-Goog-Channel-Token' => 'x' }
      expect(response).to have_http_status(:not_found)
    end

    it 'rejects a wrong verification token' do
      post '/webhooks/calendar/google', headers: {
        'X-Goog-Channel-ID' => connection.webhook_channel_id,
        'X-Goog-Channel-Token' => 'wrong'
      }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /webhooks/calendar/outlook' do
    let!(:connection) { create(:calendar_connection, :outlook, :with_webhook) }

    it 'answers the Graph validation handshake in plain text' do
      post '/webhooks/calendar/outlook', params: { validationToken: 'abc-123' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('abc-123')
      expect(response.content_type).to include('text/plain')
    end

    it 'enqueues a handle job for a valid notification' do
      expect do
        post '/webhooks/calendar/outlook',
             params: {
               value: [{ subscriptionId: connection.webhook_subscription_id,
                         clientState: connection.webhook_verification_token }]
             }.to_json,
             headers: { 'Content-Type' => 'application/json' }
      end.to have_enqueued_job(Calendar::HandleWebhookJob).with('outlook', connection.webhook_subscription_id)

      expect(response).to have_http_status(:accepted)
    end

    it 'ignores notifications with a wrong clientState' do
      expect do
        post '/webhooks/calendar/outlook',
             params: {
               value: [{ subscriptionId: connection.webhook_subscription_id, clientState: 'wrong' }]
             }.to_json,
             headers: { 'Content-Type' => 'application/json' }
      end.not_to have_enqueued_job(Calendar::HandleWebhookJob)

      expect(response).to have_http_status(:accepted)
    end
  end
end
