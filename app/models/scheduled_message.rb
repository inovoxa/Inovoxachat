# == Schema Information
#
# Table name: scheduled_messages
#
#  id              :bigint           not null, primary key
#  content         :text             not null
#  scheduled_at    :datetime         not null
#  status          :integer          default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  conversation_id :bigint           not null
#  created_by_id   :bigint
#
class ScheduledMessage < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :created_by, class_name: 'User', optional: true

  enum status: { pending: 0, sent: 1, canceled: 2, failed: 3 }

  validates :content, presence: true
  validates :scheduled_at, presence: true

  scope :due, -> { pending.where(scheduled_at: ..Time.current) }
end
