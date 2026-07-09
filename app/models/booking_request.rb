# == Schema Information
#
# Table name: booking_requests
#
#  id                :bigint           not null, primary key
#  end_time          :datetime         not null
#  guest_email       :string           not null
#  guest_name        :string           not null
#  guest_phone       :string
#  notes             :text
#  start_time        :datetime         not null
#  status            :integer          default("pending"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  booking_page_id   :bigint           not null
#  calendar_event_id :bigint
#
# Indexes
#
#  index_booking_requests_on_booking_page_id                 (booking_page_id)
#  index_booking_requests_on_booking_page_id_and_start_time  (booking_page_id,start_time)
#  index_booking_requests_on_calendar_event_id               (calendar_event_id)
#  index_booking_requests_on_guest_email                     (guest_email)
#
class BookingRequest < ApplicationRecord
  belongs_to :booking_page
  belongs_to :calendar_event, optional: true

  enum status: { pending: 0, confirmed: 1, cancelled: 2 }

  validates :guest_name, presence: { message: I18n.t('errors.validations.presence') }
  validates :guest_email, presence: { message: I18n.t('errors.validations.presence') },
                          format: { with: Devise.email_regexp, message: I18n.t('errors.validations.invalid') }
  validates :start_time, :end_time, presence: true
end
