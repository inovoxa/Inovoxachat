# == Schema Information
#
# Table name: booking_availabilities
#
#  id              :bigint           not null, primary key
#  day_of_week     :integer          not null
#  end_time        :time             not null
#  start_time      :time             not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  booking_page_id :bigint           not null
#
# Indexes
#
#  index_booking_availabilities_on_booking_page_id                  (booking_page_id)
#  index_booking_availabilities_on_booking_page_id_and_day_of_week  (booking_page_id,day_of_week)
#
class BookingAvailability < ApplicationRecord
  belongs_to :booking_page

  validates :day_of_week, presence: true, inclusion: { in: 0..6 }
  validates :start_time, :end_time, presence: true
  validate :end_after_start
  validate :no_overlap_within_day

  private

  def end_after_start
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, I18n.t('errors.validations.end_after_start')) if end_time <= start_time
  end

  def no_overlap_within_day
    return if booking_page.blank? || start_time.blank? || end_time.blank?

    siblings = booking_page.availabilities.where(day_of_week: day_of_week)
    siblings = siblings.where.not(id: id) if persisted?
    overlapping = siblings.any? do |other|
      seconds_of(start_time) < seconds_of(other.end_time) && seconds_of(other.start_time) < seconds_of(end_time)
    end
    errors.add(:base, I18n.t('errors.validations.invalid')) if overlapping
  end

  # Normaliza o campo :time para segundos desde a meia-noite (ignora a data
  # fictícia que o Rails atribui a colunas do tipo time).
  def seconds_of(value)
    value.seconds_since_midnight.to_i
  end
end
