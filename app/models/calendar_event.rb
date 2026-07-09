# == Schema Information
#
# Table name: calendar_events
#
#  id                :bigint           not null, primary key
#  all_day           :boolean          default(FALSE), not null
#  description       :text
#  end_time          :datetime         not null
#  external_event_id :string
#  location          :string
#  recurrence_rule   :string
#  source            :integer          default("internal"), not null
#  start_time        :datetime         not null
#  status            :integer          default("confirmed"), not null
#  timezone          :string           default("UTC"), not null
#  title             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  contact_id        :bigint
#  conversation_id   :bigint
#  pipeline_stage_id :bigint
#  user_id           :bigint           not null
#
# Indexes
#
#  index_calendar_events_on_account_id                 (account_id)
#  index_calendar_events_on_account_id_and_start_time  (account_id,start_time)
#  index_calendar_events_on_contact_id                 (contact_id)
#  index_calendar_events_on_conversation_id            (conversation_id)
#  index_calendar_events_on_pipeline_stage_id          (pipeline_stage_id)
#  index_calendar_events_on_start_time                 (start_time)
#  index_calendar_events_on_user_id                    (user_id)
#  uniq_calendar_events_external_id                    (account_id,external_event_id) UNIQUE WHERE (external_event_id IS NOT NULL)
#
class CalendarEvent < ApplicationRecord
  belongs_to :account
  belongs_to :user
  belongs_to :conversation, optional: true
  belongs_to :contact, optional: true
  belongs_to :pipeline_stage, optional: true

  has_many :attendees, class_name: 'CalendarEventAttendee', dependent: :destroy_async, inverse_of: :calendar_event
  accepts_nested_attributes_for :attendees, allow_destroy: true

  enum status: { confirmed: 0, tentative: 1, cancelled: 2 }
  # Prefixo evita colidir com o método `internal?` de outros mixins.
  enum source: { internal: 0, google: 1, outlook: 2 }, _prefix: :source

  validates :title, presence: { message: I18n.t('errors.validations.presence') }
  validates :start_time, presence: { message: I18n.t('errors.validations.presence') }
  validates :end_time, presence: { message: I18n.t('errors.validations.presence') }
  validate :end_after_start
  validate :recurrence_rule_parseable
  validate :timezone_valid

  # Eventos que se sobrepõem ao intervalo [from, to).
  scope :in_range, ->(from, to) { where('start_time < ? AND end_time > ?', to, from) }
  scope :recurring, -> { where.not(recurrence_rule: nil) }

  # OBS: o Kanban NÃO deve mexer em eventos. Mover um card entre estágios só
  # altera o pipeline_stage da conversa (e, se o estágio tiver mapped_status, o
  # status dela) — nunca cria, move ou cancela CalendarEvents. O vínculo
  # pipeline_stage_id aqui é apenas informativo.

  # Expande a recorrência (se houver) em ocorrências virtuais dentro do intervalo.
  # Retorna array de hashes não persistidos (ver Calendar::OccurrenceExpansionService).
  def occurrences_between(range_start, range_end)
    Calendar::OccurrenceExpansionService.new(self, range_start, range_end).expand
  end

  def recurring?
    recurrence_rule.present?
  end

  private

  def end_after_start
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, I18n.t('errors.validations.end_after_start')) if end_time <= start_time
  end

  def recurrence_rule_parseable
    return if recurrence_rule.blank?

    IceCube::Rule.from_ical(recurrence_rule)
  rescue StandardError
    errors.add(:recurrence_rule, I18n.t('errors.validations.invalid'))
  end

  def timezone_valid
    return if timezone.blank?

    errors.add(:timezone, I18n.t('errors.validations.invalid')) if ActiveSupport::TimeZone[timezone].nil?
  end
end
