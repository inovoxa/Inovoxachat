# == Schema Information
#
# Table name: booking_pages
#
#  id                        :bigint           not null, primary key
#  active                    :boolean          default(TRUE), not null
#  buffer_after_minutes      :integer          default(0), not null
#  buffer_before_minutes     :integer          default(0), not null
#  description               :text
#  duration_minutes          :integer          default(30), not null
#  max_advance_days          :integer          default(30), not null
#  min_notice_hours          :integer          default(4), not null
#  name                      :string           not null
#  slug                      :string           not null
#  timezone                  :string           default("UTC"), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
#  default_pipeline_stage_id :bigint
#  inbox_id                  :bigint           not null
#  user_id                   :bigint           not null
#
# Indexes
#
#  index_booking_pages_on_account_id                 (account_id)
#  index_booking_pages_on_default_pipeline_stage_id  (default_pipeline_stage_id)
#  index_booking_pages_on_inbox_id                   (inbox_id)
#  index_booking_pages_on_slug                       (slug) UNIQUE
#  index_booking_pages_on_user_id                    (user_id)
#
class BookingPage < ApplicationRecord
  belongs_to :account
  belongs_to :user
  belongs_to :inbox
  belongs_to :default_pipeline_stage, class_name: 'PipelineStage', optional: true

  has_many :availabilities, class_name: 'BookingAvailability', dependent: :destroy, inverse_of: :booking_page
  has_many :booking_requests, dependent: :destroy
  accepts_nested_attributes_for :availabilities, allow_destroy: true

  before_validation :ensure_slug, on: :create

  validates :name, presence: { message: I18n.t('errors.validations.presence') }
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9\-]+\z/, message: I18n.t('errors.validations.invalid') }
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :buffer_before_minutes, :buffer_after_minutes, :min_notice_hours,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_advance_days, numericality: { only_integer: true, greater_than: 0 }
  validate :timezone_valid

  scope :active, -> { where(active: true) }

  private

  def ensure_slug
    return if slug.present?

    base = name.to_s.parameterize.presence || 'agenda'
    candidate = base
    candidate = "#{base}-#{SecureRandom.hex(3)}" while candidate.blank? || BookingPage.exists?(slug: candidate)
    self.slug = candidate
  end

  def timezone_valid
    return if timezone.blank?

    errors.add(:timezone, I18n.t('errors.validations.invalid')) if ActiveSupport::TimeZone[timezone].nil?
  end
end
