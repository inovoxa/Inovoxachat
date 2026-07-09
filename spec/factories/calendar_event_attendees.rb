# frozen_string_literal: true

FactoryBot.define do
  factory :calendar_event_attendee do
    calendar_event
    sequence(:email) { |n| "convidado#{n}@example.com" }
    sequence(:name) { |n| "Convidado #{n}" }
    response_status { :pending }
  end
end
