# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public Booking Pages API', type: :request do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let!(:page) do
    create(:booking_page, account: account, user: owner, inbox: inbox,
                          duration_minutes: 30, min_notice_hours: 0, timezone: 'UTC')
  end

  before do
    create(:booking_availability, booking_page: page, day_of_week: 1, start_time: '09:00', end_time: '11:00')
  end

  describe 'GET /public/api/v1/booking_pages/:slug' do
    it 'returns public-safe page data' do
      get "/public/api/v1/booking_pages/#{page.slug}"

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['name']).to eq(page.name)
      expect(body['available_weekdays']).to eq([1])
    end

    it 'returns 404 for an inactive page' do
      page.update!(active: false)
      get "/public/api/v1/booking_pages/#{page.slug}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /public/api/v1/booking_pages/:slug/available_slots' do
    it 'returns the slots for the date' do
      travel_to(Time.utc(2026, 7, 5, 8, 0)) do
        get "/public/api/v1/booking_pages/#{page.slug}/available_slots", params: { date: '2026-07-06' }

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['payload'].length).to eq(4)
      end
    end
  end

  describe 'POST /public/api/v1/booking_pages/:slug/bookings' do
    let(:params) do
      { guest_name: 'Fulano', guest_email: 'fulano@example.com', notes: 'oi', start_time: '2026-07-06T09:00:00Z' }
    end

    it 'creates a contact, conversation, calendar event and booking request' do
      travel_to(Time.utc(2026, 7, 5, 8, 0)) do
        expect do
          post "/public/api/v1/booking_pages/#{page.slug}/bookings", params: params
        end.to change(BookingRequest, :count).by(1)
          .and change(CalendarEvent, :count).by(1)
          .and change(Conversation, :count).by(1)
          .and change(Contact, :count).by(1)

        expect(response).to have_http_status(:created)
        booking = BookingRequest.last
        expect(booking).to be_confirmed
        expect(booking.calendar_event).to be_present
        expect(response.parsed_body['ics_url']).to be_present
      end
    end

    it 'rejects a slot that is not available' do
      travel_to(Time.utc(2026, 7, 5, 8, 0)) do
        post "/public/api/v1/booking_pages/#{page.slug}/bookings",
             params: params.merge(start_time: '2026-07-06T20:00:00Z')

        expect(response).to have_http_status(:unprocessable_entity)
        expect(BookingRequest.count).to eq(0)
      end
    end
  end

  describe 'GET /public/api/v1/booking_pages/:slug/bookings/:id/ics' do
    it 'returns the ics for a confirmed booking' do
      travel_to(Time.utc(2026, 7, 5, 8, 0)) do
        post "/public/api/v1/booking_pages/#{page.slug}/bookings",
             params: { guest_name: 'Fulano', guest_email: 'f@example.com', start_time: '2026-07-06T09:00:00Z' }
        booking_id = response.parsed_body['id']

        get "/public/api/v1/booking_pages/#{page.slug}/bookings/#{booking_id}/ics"

        expect(response).to have_http_status(:success)
        expect(response.body).to include('BEGIN:VCALENDAR')
        expect(response.body).to include('BEGIN:VEVENT')
      end
    end
  end
end
