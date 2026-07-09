require 'rails_helper'

RSpec.describe 'Booking Pages Admin API', type: :request do
  let!(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }

  describe 'GET /api/v1/accounts/{account.id}/booking_pages' do
    let!(:page) { create(:booking_page, account: account, user: admin, inbox: inbox) }

    it 'forbids agents' do
      get "/api/v1/accounts/#{account.id}/booking_pages",
          headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists pages for administrators' do
      get "/api/v1/accounts/#{account.id}/booking_pages",
          headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].first['name']).to eq(page.name)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/booking_pages' do
    it 'creates a page with nested availabilities' do
      expect do
        post "/api/v1/accounts/#{account.id}/booking_pages",
             headers: admin.create_new_auth_token,
             params: {
               booking_page: {
                 name: 'Comercial', inbox_id: inbox.id, user_id: admin.id,
                 availabilities_attributes: [{ day_of_week: 1, start_time: '09:00', end_time: '17:00' }]
               }
             }, as: :json
      end.to change(BookingPage, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(BookingPage.last.availabilities.count).to eq(1)
      expect(response.parsed_body['public_url']).to include('/booking/')
    end
  end
end
