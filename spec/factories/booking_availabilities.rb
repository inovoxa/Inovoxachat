# frozen_string_literal: true

FactoryBot.define do
  factory :booking_availability do
    booking_page
    day_of_week { 1 }
    start_time { '09:00' }
    end_time { '17:00' }
  end
end
