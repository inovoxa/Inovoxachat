require 'rails_helper'

RSpec.describe 'Calendar Events API', type: :request do
  let!(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/{account.id}/calendar_events' do
    let(:range) { { start_date: '2026-07-01', end_date: '2026-07-31' } }

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/calendar_events", params: range

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      it 'returns events overlapping the range' do
        event = create(:calendar_event, account: account, user: agent,
                                        start_time: Time.zone.parse('2026-07-10 10:00'),
                                        end_time: Time.zone.parse('2026-07-10 11:00'))
        create(:calendar_event, account: account, user: agent,
                                start_time: Time.zone.parse('2026-08-10 10:00'),
                                end_time: Time.zone.parse('2026-08-10 11:00'))

        get "/api/v1/accounts/#{account.id}/calendar_events",
            headers: agent.create_new_auth_token, params: range, as: :json

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        expect(body['payload'].length).to eq(1)
        expect(body['payload'].first['title']).to eq(event.title)
      end

      it 'expands recurring events into occurrences' do
        create(:calendar_event, account: account, user: agent,
                                start_time: Time.zone.parse('2026-07-06 09:00'),
                                end_time: Time.zone.parse('2026-07-06 10:00'),
                                recurrence_rule: 'FREQ=WEEKLY;BYDAY=MO')

        get "/api/v1/accounts/#{account.id}/calendar_events",
            headers: agent.create_new_auth_token, params: range, as: :json

        expect(response.parsed_body['payload'].length).to eq(4)
      end

      it 'filters by user_id' do
        create(:calendar_event, account: account, user: agent,
                                start_time: Time.zone.parse('2026-07-10 10:00'),
                                end_time: Time.zone.parse('2026-07-10 11:00'))
        create(:calendar_event, account: account, user: other_agent,
                                start_time: Time.zone.parse('2026-07-11 10:00'),
                                end_time: Time.zone.parse('2026-07-11 11:00'))

        get "/api/v1/accounts/#{account.id}/calendar_events",
            headers: agent.create_new_auth_token,
            params: range.merge(user_id: other_agent.id), as: :json

        payload = response.parsed_body['payload']
        expect(payload.length).to eq(1)
        expect(payload.first['user_id']).to eq(other_agent.id)
      end

      it 'rejects a range larger than the allowed maximum' do
        get "/api/v1/accounts/#{account.id}/calendar_events",
            headers: agent.create_new_auth_token,
            params: { start_date: '2026-01-01', end_date: '2026-12-31' }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/calendar_events' do
    it 'creates an event with nested attendees owned by the current user' do
      expect do
        post "/api/v1/accounts/#{account.id}/calendar_events",
             headers: agent.create_new_auth_token,
             params: {
               calendar_event: {
                 title: 'Reunião',
                 start_time: '2026-07-10T10:00:00Z',
                 end_time: '2026-07-10T11:00:00Z',
                 attendees_attributes: [{ email: 'guest@example.com', name: 'Guest' }]
               }
             }, as: :json
      end.to change(CalendarEvent, :count).by(1)

      expect(response).to have_http_status(:success)
      event = CalendarEvent.last
      expect(event.user_id).to eq(agent.id)
      expect(event.attendees.first.email).to eq('guest@example.com')
    end
  end

  describe 'PATCH/DELETE authorization' do
    let!(:event) do
      create(:calendar_event, account: account, user: agent,
                              start_time: Time.zone.parse('2026-07-10 10:00'),
                              end_time: Time.zone.parse('2026-07-10 11:00'))
    end

    it 'lets the owner update the event' do
      patch "/api/v1/accounts/#{account.id}/calendar_events/#{event.id}",
            headers: agent.create_new_auth_token,
            params: { calendar_event: { title: 'Novo título' } }, as: :json

      expect(response).to have_http_status(:success)
      expect(event.reload.title).to eq('Novo título')
    end

    it 'forbids another agent from updating the event' do
      patch "/api/v1/accounts/#{account.id}/calendar_events/#{event.id}",
            headers: other_agent.create_new_auth_token,
            params: { calendar_event: { title: 'Hack' } }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(event.reload.title).not_to eq('Hack')
    end

    it 'lets an administrator delete another user event' do
      expect do
        delete "/api/v1/accounts/#{account.id}/calendar_events/#{event.id}",
               headers: admin.create_new_auth_token, as: :json
      end.to change(CalendarEvent, :count).by(-1)

      expect(response).to have_http_status(:success)
    end
  end
end
