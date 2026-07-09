# frozen_string_literal: true

FactoryBot.define do
  factory :booking_request do
    booking_page
    guest_name { 'Fulano de Tal' }
    sequence(:guest_email) { |n| "guest#{n}@example.com" }
    start_time { 1.day.from_now.change(hour: 10) }
    end_time { 1.day.from_now.change(hour: 10, min: 30) }
    status { :pending }
  end
end
