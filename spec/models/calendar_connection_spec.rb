# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CalendarConnection do
  describe 'validations' do
    it 'enforces one connection per provider per user' do
      connection = create(:calendar_connection)
      duplicate = build(:calendar_connection, user: connection.user, account: connection.account, provider: :google)
      expect(duplicate).not_to be_valid
    end

    it 'allows the same user to connect both providers' do
      connection = create(:calendar_connection)
      outlook = build(:calendar_connection, :outlook, user: connection.user, account: connection.account)
      expect(outlook).to be_valid
    end
  end

  describe '#token_expired?' do
    it 'is true when expires_at is blank' do
      expect(build(:calendar_connection, expires_at: nil).token_expired?).to be(true)
    end

    it 'is true within the 5 minute safety window' do
      expect(build(:calendar_connection, expires_at: 2.minutes.from_now).token_expired?).to be(true)
    end

    it 'is false for a fresh token' do
      expect(build(:calendar_connection, expires_at: 1.hour.from_now).token_expired?).to be(false)
    end
  end

  describe '#pushable_events' do
    it 'returns only internal events of the connection owner' do
      connection = create(:calendar_connection)
      own_internal = create(:calendar_event, account: connection.account, user: connection.user, source: :internal)
      create(:calendar_event, account: connection.account, user: connection.user, source: :google)
      create(:calendar_event, account: connection.account, source: :internal) # de outro usuário

      expect(connection.pushable_events).to contain_exactly(own_internal)
    end
  end
end
