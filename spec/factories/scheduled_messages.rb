# frozen_string_literal: true

FactoryBot.define do
  factory :scheduled_message do
    conversation
    account { conversation.account }
    content { 'Mensagem agendada' }
    scheduled_at { 1.hour.from_now }
  end
end
