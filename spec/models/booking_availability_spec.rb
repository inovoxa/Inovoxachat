# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BookingAvailability do
  let(:page) { create(:booking_page) }

  it 'rejects end_time before start_time' do
    availability = build(:booking_availability, booking_page: page, start_time: '17:00', end_time: '09:00')
    expect(availability).not_to be_valid
  end

  it 'rejects an out-of-range day_of_week' do
    availability = build(:booking_availability, booking_page: page, day_of_week: 9)
    expect(availability).not_to be_valid
  end

  it 'rejects overlapping ranges within the same day' do
    create(:booking_availability, booking_page: page, day_of_week: 1, start_time: '09:00', end_time: '12:00')
    overlapping = build(:booking_availability, booking_page: page, day_of_week: 1, start_time: '11:00', end_time: '13:00')
    expect(overlapping).not_to be_valid
  end

  it 'allows non-overlapping ranges within the same day' do
    create(:booking_availability, booking_page: page, day_of_week: 1, start_time: '09:00', end_time: '12:00')
    adjacent = build(:booking_availability, booking_page: page, day_of_week: 1, start_time: '13:00', end_time: '17:00')
    expect(adjacent).to be_valid
  end
end
