# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BookingMailer do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:page) { create(:booking_page, account: account, user: owner) }
  let(:event) do
    create(:calendar_event, account: account, user: owner, title: 'Reunião',
                            start_time: 1.day.from_now, end_time: 1.day.from_now + 30.minutes)
  end
  let(:booking_request) do
    create(:booking_request, booking_page: page, calendar_event: event, status: :confirmed,
                             guest_email: 'guest@example.com')
  end

  before do
    allow_any_instance_of(described_class).to receive(:smtp_config_set_or_development?).and_return(true)
  end

  describe '#confirmation_email' do
    let(:mail) { described_class.with(account: account).confirmation_email(booking_request) }

    it 'is sent to the guest with an ics attachment' do
      expect(mail.to).to eq(['guest@example.com'])
      expect(mail.attachments.map(&:filename)).to include('agendamento.ics')
      ics = mail.attachments['agendamento.ics'].body.raw_source
      expect(ics).to include('BEGIN:VEVENT')
    end
  end

  describe '#agent_notification' do
    let(:mail) { described_class.with(account: account).agent_notification(booking_request) }

    it 'is sent to the owner agent' do
      expect(mail.to).to eq([owner.email])
    end
  end
end
