# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Booking::AvailableSlotsService do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:page) do
    create(:booking_page, account: account, user: owner, inbox: inbox,
                          duration_minutes: 30, min_notice_hours: 0, max_advance_days: 30, timezone: 'UTC')
  end

  before do
    # Segunda-feira 09:00-11:00 (4 slots de 30 min).
    create(:booking_availability, booking_page: page, day_of_week: 1, start_time: '09:00', end_time: '11:00')
  end

  # 2026-07-06 é uma segunda-feira.
  let(:monday) { '2026-07-06' }

  it 'returns the slots of an available weekday' do
    travel_to(Time.utc(2026, 7, 5, 8, 0)) do
      slots = described_class.new(page, monday).slots
      expect(slots.length).to eq(4)
      expect(slots.first[:start_time]).to eq('2026-07-06T09:00:00Z')
    end
  end

  it 'returns no slots for a weekday without availability' do
    travel_to(Time.utc(2026, 7, 5, 8, 0)) do
      # 2026-07-07 é terça-feira, sem disponibilidade cadastrada.
      expect(described_class.new(page, '2026-07-07').slots).to be_empty
    end
  end

  it 'excludes slots blocked by an existing event (with buffers)' do
    create(:calendar_event, account: account, user: owner,
                            start_time: Time.utc(2026, 7, 6, 9, 0),
                            end_time: Time.utc(2026, 7, 6, 9, 30),
                            status: :confirmed)
    travel_to(Time.utc(2026, 7, 6, 7, 0)) do
      starts = described_class.new(page, monday).slots.map { |s| s[:start_time] }
      expect(starts).not_to include('2026-07-06T09:00:00Z')
      expect(starts).to include('2026-07-06T09:30:00Z')
    end
  end

  it 'respects the minimum notice' do
    page.update!(min_notice_hours: 1)
    travel_to(Time.utc(2026, 7, 6, 8, 50)) do
      starts = described_class.new(page, monday).slots.map { |s| s[:start_time] }
      # Antecedência mínima empurra o primeiro horário para 09:50.
      expect(starts).to eq(['2026-07-06T10:00:00Z', '2026-07-06T10:30:00Z'])
    end
  end

  it 'returns no slots beyond the max advance horizon' do
    travel_to(Time.utc(2026, 7, 5, 8, 0)) do
      far = (Time.zone.today + 60.days).to_s
      expect(described_class.new(page, far).slots).to be_empty
    end
  end

  it 'blocks slots overlapping a recurring event occurrence' do
    create(:calendar_event, account: account, user: owner,
                            start_time: Time.utc(2026, 6, 29, 10, 0), # segunda anterior
                            end_time: Time.utc(2026, 6, 29, 10, 30),
                            status: :confirmed,
                            recurrence_rule: 'FREQ=WEEKLY;BYDAY=MO')
    travel_to(Time.utc(2026, 7, 6, 7, 0)) do
      starts = described_class.new(page, monday).slots.map { |s| s[:start_time] }
      expect(starts).not_to include('2026-07-06T10:00:00Z')
    end
  end
end
