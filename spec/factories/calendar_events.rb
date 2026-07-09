# frozen_string_literal: true

FactoryBot.define do
  factory :calendar_event do
    account
    user { association :user, account: account }
    sequence(:title) { |n| "Evento #{n}" }
    start_time { 1.hour.from_now }
    end_time { 2.hours.from_now }
    all_day { false }
    timezone { 'UTC' }
    status { :confirmed }
    source { :internal }

    trait :weekly do
      recurrence_rule { 'FREQ=WEEKLY;BYDAY=MO' }
    end

    trait :with_attendee do
      after(:create) do |event|
        create(:calendar_event_attendee, calendar_event: event)
      end
    end
  end
end
