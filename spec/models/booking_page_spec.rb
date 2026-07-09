# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BookingPage do
  let(:account) { create(:account) }

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:inbox) }
    it { is_expected.to belong_to(:default_pipeline_stage).optional }
    it { is_expected.to have_many(:availabilities).dependent(:destroy) }
  end

  describe 'slug' do
    it 'auto-generates a slug from the name on create' do
      page = create(:booking_page, account: account, name: 'Reunião Comercial')
      expect(page.slug).to eq('reuniao-comercial')
    end

    it 'ensures uniqueness by appending a suffix' do
      create(:booking_page, account: account, name: 'Suporte', slug: 'suporte')
      page = create(:booking_page, account: account, name: 'Suporte')
      expect(page.slug).to start_with('suporte-')
      expect(page.slug).not_to eq('suporte')
    end
  end

  describe 'validations' do
    it 'rejects a non-positive duration' do
      page = build(:booking_page, account: account, duration_minutes: 0)
      expect(page).not_to be_valid
    end

    it 'rejects an invalid timezone' do
      page = build(:booking_page, account: account, timezone: 'Mars/Phobos')
      expect(page).not_to be_valid
    end
  end
end
