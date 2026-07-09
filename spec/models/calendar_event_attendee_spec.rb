# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CalendarEventAttendee do
  describe 'associations' do
    it { is_expected.to belong_to(:calendar_event) }
    it { is_expected.to belong_to(:user).optional }
  end

  describe 'validations' do
    subject { build(:calendar_event_attendee) }

    it 'requires an email' do
      attendee = build(:calendar_event_attendee, email: nil)
      expect(attendee).not_to be_valid
      expect(attendee.errors[:email]).to be_present
    end

    it 'rejects a malformed email' do
      attendee = build(:calendar_event_attendee, email: 'not-an-email')
      expect(attendee).not_to be_valid
    end

    it 'enforces uniqueness of email within an event' do
      event = create(:calendar_event)
      create(:calendar_event_attendee, calendar_event: event, email: 'dup@example.com')
      duplicate = build(:calendar_event_attendee, calendar_event: event, email: 'dup@example.com')
      expect(duplicate).not_to be_valid
    end
  end
end
