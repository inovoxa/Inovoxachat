require 'rails_helper'

RSpec.describe ScheduledMessage do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:conversation) }
    it { is_expected.to belong_to(:created_by).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_presence_of(:scheduled_at) }
  end

  describe '.due' do
    let(:account) { create(:account) }
    let(:conversation) { create(:conversation, account: account) }

    it 'returns only pending messages scheduled in the past' do
      due = create(:scheduled_message, conversation: conversation, scheduled_at: 5.minutes.ago)
      create(:scheduled_message, conversation: conversation, scheduled_at: 1.hour.from_now)
      create(:scheduled_message, conversation: conversation, scheduled_at: 5.minutes.ago, status: :sent)

      expect(described_class.due).to contain_exactly(due)
    end
  end
end
