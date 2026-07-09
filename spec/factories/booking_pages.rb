# frozen_string_literal: true

FactoryBot.define do
  factory :booking_page do
    account
    user { association :user, account: account }
    inbox { association :inbox, account: account }
    sequence(:name) { |n| "Agenda #{n}" }
    duration_minutes { 30 }
    min_notice_hours { 0 }
    max_advance_days { 30 }
    timezone { 'UTC' }
    active { true }

    trait :with_weekday_availability do
      after(:create) do |page|
        # Segunda a sexta, 09:00-17:00.
        (1..5).each do |dow|
          create(:booking_availability, booking_page: page, day_of_week: dow,
                                        start_time: '09:00', end_time: '17:00')
        end
      end
    end
  end
end
