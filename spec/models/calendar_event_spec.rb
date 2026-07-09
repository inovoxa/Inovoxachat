# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CalendarEvent do
  let(:account) { create(:account) }

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:conversation).optional }
    it { is_expected.to belong_to(:contact).optional }
    it { is_expected.to belong_to(:pipeline_stage).optional }
    it { is_expected.to have_many(:attendees).dependent(:destroy_async) }
  end

  describe 'validations' do
    it 'requires a title' do
      event = build(:calendar_event, account: account, title: nil)
      expect(event).not_to be_valid
      expect(event.errors[:title]).to be_present
    end

    it 'rejects end_time before or equal to start_time' do
      event = build(:calendar_event, account: account, start_time: 1.hour.from_now, end_time: 1.hour.from_now)
      expect(event).not_to be_valid
      expect(event.errors[:end_time]).to be_present
    end

    it 'rejects an unparseable recurrence_rule' do
      event = build(:calendar_event, account: account, recurrence_rule: 'NOT-A-RULE;;')
      expect(event).not_to be_valid
      expect(event.errors[:recurrence_rule]).to be_present
    end

    it 'accepts a valid RRULE' do
      event = build(:calendar_event, account: account, recurrence_rule: 'FREQ=WEEKLY;BYDAY=MO,WE')
      expect(event).to be_valid
    end

    it 'rejects an invalid timezone' do
      event = build(:calendar_event, account: account, timezone: 'Mars/Phobos')
      expect(event).not_to be_valid
      expect(event.errors[:timezone]).to be_present
    end
  end

  describe 'enums' do
    it 'defines the source enum with a prefix' do
      event = build(:calendar_event, account: account, source: :google)
      expect(event).to be_source_google
    end
  end

  describe '.in_range' do
    it 'returns events overlapping the interval' do
      inside = create(:calendar_event, account: account, start_time: Time.zone.parse('2026-07-10 10:00'),
                                       end_time: Time.zone.parse('2026-07-10 11:00'))
      create(:calendar_event, account: account, start_time: Time.zone.parse('2026-08-01 10:00'),
                              end_time: Time.zone.parse('2026-08-01 11:00'))

      result = account.calendar_events.in_range(
        Time.zone.parse('2026-07-01 00:00'), Time.zone.parse('2026-07-31 23:59')
      )
      expect(result).to contain_exactly(inside)
    end
  end

  describe '#occurrences_between' do
    it 'expands a weekly recurrence into virtual occurrences' do
      event = create(:calendar_event, account: account,
                                      start_time: Time.zone.parse('2026-07-06 09:00'), # segunda-feira
                                      end_time: Time.zone.parse('2026-07-06 10:00'),
                                      recurrence_rule: 'FREQ=WEEKLY;BYDAY=MO')

      occurrences = event.occurrences_between(
        Time.zone.parse('2026-07-01 00:00'), Time.zone.parse('2026-07-31 23:59')
      )

      # Segundas de julho/2026: 6, 13, 20, 27 => 4 ocorrências.
      expect(occurrences.length).to eq(4)
      expect(occurrences.first[:occurrence]).to be(true)
      expect(occurrences.first[:occurrence_id]).to include("#{event.id}_")
    end

    it 'preserves the event duration in each occurrence' do
      event = create(:calendar_event, account: account,
                                      start_time: Time.zone.parse('2026-07-06 09:00'),
                                      end_time: Time.zone.parse('2026-07-06 10:30'),
                                      recurrence_rule: 'FREQ=DAILY')

      occurrences = event.occurrences_between(
        Time.zone.parse('2026-07-06 00:00'), Time.zone.parse('2026-07-08 23:59')
      )
      first = occurrences.first
      expect(first[:end_time] - first[:start_time]).to eq(90 * 60)
    end

    it 'caps runaway recurrences at MAX_OCCURRENCES' do
      event = create(:calendar_event, account: account,
                                      start_time: Time.zone.parse('2026-01-01 09:00'),
                                      end_time: Time.zone.parse('2026-01-01 10:00'),
                                      recurrence_rule: 'FREQ=DAILY')

      occurrences = event.occurrences_between(
        Time.zone.parse('2026-01-01 00:00'), Time.zone.parse('2027-12-31 23:59')
      )
      expect(occurrences.length).to eq(Calendar::OccurrenceExpansionService::MAX_OCCURRENCES)
    end

    it 'returns a single occurrence for a non-recurring event' do
      event = create(:calendar_event, account: account,
                                      start_time: Time.zone.parse('2026-07-10 09:00'),
                                      end_time: Time.zone.parse('2026-07-10 10:00'))

      occurrences = event.occurrences_between(
        Time.zone.parse('2026-07-01 00:00'), Time.zone.parse('2026-07-31 23:59')
      )
      expect(occurrences.length).to eq(1)
      expect(occurrences.first[:occurrence]).to be(false)
    end
  end
end
