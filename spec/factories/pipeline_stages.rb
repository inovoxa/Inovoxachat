# frozen_string_literal: true

FactoryBot.define do
  factory :pipeline_stage do
    pipeline
    sequence(:name) { |n| "Stage #{n}" }
    sequence(:position) { |n| n }
    color { '#1F93FF' }
  end
end
