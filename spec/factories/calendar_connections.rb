# frozen_string_literal: true

FactoryBot.define do
  factory :calendar_connection do
    account
    user { association :user, account: account }
    provider { :google }
    access_token { 'access-token' }
    refresh_token { 'refresh-token' }
    expires_at { 1.hour.from_now }
    sync_enabled { true }

    trait :outlook do
      provider { :outlook }
    end

    trait :with_webhook do
      webhook_channel_id { SecureRandom.uuid }
      webhook_resource_id { 'resource-1' }
      webhook_subscription_id { 'sub-1' }
      webhook_verification_token { 'verify-token' }
      webhook_expires_at { 2.days.from_now }
    end
  end
end
