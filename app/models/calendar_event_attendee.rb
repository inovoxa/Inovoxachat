# == Schema Information
#
# Table name: calendar_event_attendees
#
#  id                :bigint           not null, primary key
#  email             :string           not null
#  name              :string
#  response_status   :integer          default("pending"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  calendar_event_id :bigint           not null
#  user_id           :bigint
#
# Indexes
#
#  index_calendar_event_attendees_on_calendar_event_id            (calendar_event_id)
#  index_calendar_event_attendees_on_calendar_event_id_and_email  (calendar_event_id,email) UNIQUE
#  index_calendar_event_attendees_on_user_id                      (user_id)
#
class CalendarEventAttendee < ApplicationRecord
  belongs_to :calendar_event
  belongs_to :user, optional: true

  enum response_status: { pending: 0, accepted: 1, declined: 2 }

  validates :email, presence: { message: I18n.t('errors.validations.presence') },
                    format: { with: Devise.email_regexp, message: I18n.t('errors.validations.invalid') }
  validates :email, uniqueness: { scope: :calendar_event_id }
end
