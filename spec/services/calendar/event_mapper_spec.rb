# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Calendar::EventMapper do
  let(:account) { create(:account) }
  let(:event) do
    create(:calendar_event, account: account, title: 'Reunião',
                            start_time: Time.utc(2026, 7, 10, 13, 0),
                            end_time: Time.utc(2026, 7, 10, 14, 0),
                            recurrence_rule: 'FREQ=WEEKLY;BYDAY=MO,WE')
  end

  describe '.to_google' do
    it 'maps core fields, recurrence and the anti-loop marker' do
      payload = described_class.to_google(event)

      expect(payload[:summary]).to eq('Reunião')
      expect(payload[:recurrence]).to eq(['RRULE:FREQ=WEEKLY;BYDAY=MO,WE'])
      expect(payload[:extendedProperties][:private][:chatwoot_id]).to eq(event.id.to_s)
      expect(payload[:start][:dateTime]).to eq('2026-07-10T13:00:00Z')
    end

    it 'uses date-only blocks for all-day events' do
      event.update!(all_day: true)
      payload = described_class.to_google(event)
      expect(payload[:start]).to eq(date: '2026-07-10')
    end
  end

  describe '.from_google' do
    it 'extracts attributes including RRULE and the chatwoot marker' do
      attrs = described_class.from_google(
        'id' => 'g-1', 'summary' => 'Externo', 'status' => 'tentative',
        'updated' => '2026-07-01T10:00:00Z',
        'start' => { 'dateTime' => '2026-07-10T13:00:00Z', 'timeZone' => 'America/Sao_Paulo' },
        'end' => { 'dateTime' => '2026-07-10T14:00:00Z' },
        'recurrence' => ['RRULE:FREQ=DAILY'],
        'extendedProperties' => { 'private' => { 'chatwoot_id' => '42' } }
      )

      expect(attrs[:title]).to eq('Externo')
      expect(attrs[:status]).to eq(:tentative)
      expect(attrs[:recurrence_rule]).to eq('FREQ=DAILY')
      expect(attrs[:chatwoot_id]).to eq('42')
      expect(attrs[:timezone]).to eq('America/Sao_Paulo')
    end
  end

  describe 'Graph recurrence conversion' do
    it 'converts a weekly RRULE into a Graph pattern and back' do
      payload = described_class.to_graph(event)
      expect(payload[:recurrence][:pattern]).to include(type: 'weekly', daysOfWeek: %w[monday wednesday])

      round_trip = described_class.from_graph(
        'subject' => 'X',
        'start' => { 'dateTime' => '2026-07-10T13:00:00', 'timeZone' => 'UTC' },
        'end' => { 'dateTime' => '2026-07-10T14:00:00', 'timeZone' => 'UTC' },
        'recurrence' => { 'pattern' => { 'type' => 'weekly', 'interval' => 1,
                                         'daysOfWeek' => %w[monday wednesday] } }
      )
      expect(round_trip[:recurrence_rule]).to eq('FREQ=WEEKLY;BYDAY=MO,WE')
    end

    it 'returns nil recurrence for unsupported Graph patterns' do
      attrs = described_class.from_graph(
        'subject' => 'X',
        'start' => { 'dateTime' => '2026-07-10T13:00:00', 'timeZone' => 'UTC' },
        'end' => { 'dateTime' => '2026-07-10T14:00:00', 'timeZone' => 'UTC' },
        'recurrence' => { 'pattern' => { 'type' => 'relativeYearly' } }
      )
      expect(attrs[:recurrence_rule]).to be_nil
    end
  end
end
