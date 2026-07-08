class ScheduledMessages::ProcessJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    ScheduledMessage.due.find_each(batch_size: 100) do |scheduled_message|
      deliver(scheduled_message)
    end
  end

  private

  def deliver(scheduled_message)
    Messages::MessageBuilder.new(
      scheduled_message.created_by,
      scheduled_message.conversation,
      ActionController::Parameters.new(content: scheduled_message.content, message_type: 'outgoing')
    ).perform
    scheduled_message.sent!
  rescue StandardError => e
    Rails.logger.error("ScheduledMessage #{scheduled_message.id} failed: #{e.message}")
    scheduled_message.failed!
  end
end
