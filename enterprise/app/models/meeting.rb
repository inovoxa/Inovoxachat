# Calendário — reunião. Multi-tenant (account_id). Participantes = lista de user ids.
class Meeting < ApplicationRecord
  belongs_to :account
  belongs_to :company, optional: true
  belongs_to :organizer, class_name: 'User', optional: true

  validates :title, presence: true
  validates :start_at, presence: true

  before_validation :normalize_participants

  scope :in_range, ->(from, to) { where(start_at: from..to) }
  scope :ordered, -> { order(:start_at) }

  private

  def normalize_participants
    self.participant_ids = Array(participant_ids).map(&:to_i).uniq.reject(&:zero?)
  end
end
