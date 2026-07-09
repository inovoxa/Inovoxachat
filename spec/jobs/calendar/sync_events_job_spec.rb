# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Calendar::SyncEventsJob do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:connection) do
    create(:calendar_connection, account: account, user: agent, expires_at: 1.hour.from_now)
  end

  let(:events_url) { %r{www\.googleapis\.com/calendar/v3/calendars/primary/events} }

  def google_item(id:, summary: 'Remoto', updated: 1.minute.ago, status: 'confirmed', chatwoot_id: nil)
    item = {
      'id' => id,
      'summary' => summary,
      'status' => status,
      'updated' => updated.utc.iso8601,
      'start' => { 'dateTime' => 1.day.from_now.utc.iso8601, 'timeZone' => 'UTC' },
      'end' => { 'dateTime' => (1.day.from_now + 1.hour).utc.iso8601, 'timeZone' => 'UTC' }
    }
    item['extendedProperties'] = { 'private' => { 'chatwoot_id' => chatwoot_id.to_s } } if chatwoot_id
    item
  end

  def stub_list(items:, sync_token: 'next-token')
    stub_request(:get, events_url)
      .to_return(status: 200, body: { items: items, nextSyncToken: sync_token }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  it 'does nothing when the connection is missing or disabled' do
    connection.update!(sync_enabled: false)
    expect { described_class.perform_now(connection.id) }.not_to change(CalendarEvent, :count)
  end

  describe 'pull' do
    it 'creates a local event from a remote item and stores the sync token' do
      stub_list(items: [google_item(id: 'g-1')])

      expect { described_class.perform_now(connection.id) }.to change(CalendarEvent, :count).by(1)

      event = CalendarEvent.last
      expect(event.external_event_id).to eq('g-1')
      expect(event.source).to eq('google')
      expect(event.user_id).to eq(agent.id)
      expect(connection.reload.sync_token).to eq('next-token')
      expect(connection.last_synced_at).to be_present
    end

    it 'recognizes the chatwoot_id marker and does not duplicate our own event' do
      local = create(:calendar_event, account: account, user: agent, source: :internal,
                                      title: 'Local original')
      stub_list(items: [google_item(id: 'g-echo', summary: 'Local original', updated: 1.hour.ago,
                                    chatwoot_id: local.id)])

      expect { described_class.perform_now(connection.id) }.not_to change(CalendarEvent, :count)
      expect(local.reload.external_event_id).to eq('g-echo')
    end

    it 'marks the local event cancelled when the remote is cancelled' do
      event = create(:calendar_event, account: account, user: agent, source: :google,
                                      external_event_id: 'g-2')
      stub_list(items: [google_item(id: 'g-2', status: 'cancelled')])

      described_class.perform_now(connection.id)
      expect(event.reload.status).to eq('cancelled')
    end

    it 'keeps local changes when the local copy is newer (conflict: local wins)' do
      event = create(:calendar_event, account: account, user: agent, source: :google,
                                      external_event_id: 'g-3', title: 'Editado localmente')
      stub_list(items: [google_item(id: 'g-3', summary: 'Antigo remoto', updated: 1.day.ago)])

      described_class.perform_now(connection.id)
      expect(event.reload.title).to eq('Editado localmente')
    end

    it 'overwrites the local copy when the remote is newer (conflict: remote wins)' do
      event = create(:calendar_event, account: account, user: agent, source: :google,
                                      external_event_id: 'g-4', title: 'Velho local')
      event.update_column(:updated_at, 2.days.ago) # rubocop:disable Rails/SkipsModelValidations
      stub_list(items: [google_item(id: 'g-4', summary: 'Novo remoto', updated: 1.minute.ago)])

      described_class.perform_now(connection.id)
      expect(event.reload.title).to eq('Novo remoto')
    end

    it 'resets the sync token and retries a full sync on 410 GONE' do
      connection.update!(sync_token: 'stale-token')
      stub_request(:get, events_url)
        .to_return({ status: 410, body: '{}' },
                   { status: 200, body: { items: [google_item(id: 'g-5')], nextSyncToken: 'fresh' }.to_json,
                     headers: { 'Content-Type' => 'application/json' } })

      expect { described_class.perform_now(connection.id) }.to change(CalendarEvent, :count).by(1)
      expect(connection.reload.sync_token).to eq('fresh')
    end
  end

  describe 'push' do
    before { stub_list(items: []) }

    it 'creates internal events on the provider and stores the external id' do
      event = create(:calendar_event, account: account, user: agent, source: :internal)
      stub_request(:post, events_url)
        .to_return(status: 200, body: { id: 'created-remote' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      described_class.perform_now(connection.id)
      expect(event.reload.external_event_id).to eq('created-remote')
    end

    it 'patches mirrored events changed since the last sync' do
      connection.update!(last_synced_at: 1.hour.ago)
      create(:calendar_event, account: account, user: agent, source: :internal,
                              external_event_id: 'g-up', title: 'Atualizado')
      patch_stub = stub_request(:patch, %r{/calendars/primary/events/g-up})
                   .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

      described_class.perform_now(connection.id)
      expect(patch_stub).to have_been_requested
    end
  end
end
