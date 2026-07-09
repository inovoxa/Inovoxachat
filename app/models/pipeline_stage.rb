# == Schema Information
#
# Table name: pipeline_stages
#
#  id          :bigint           not null, primary key
#  color       :string           default("#1F93FF"), not null
#  name        :string           not null
#  position    :integer          default(1), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  pipeline_id :bigint           not null
#
# Indexes
#
#  index_pipeline_stages_on_pipeline_id               (pipeline_id)
#  index_pipeline_stages_on_pipeline_id_and_position  (pipeline_id,position)
#
class PipelineStage < ApplicationRecord
  belongs_to :pipeline

  has_many :conversations, dependent: :nullify
  has_many :contacts, dependent: :nullify
  has_many :calendar_events, dependent: :nullify
  has_many :booking_pages, foreign_key: :default_pipeline_stage_id, dependent: :nullify, inverse_of: :default_pipeline_stage

  # Espelha o enum de status da Conversation; o card migra para cá quando a
  # conversa assume o status correspondente. nil = sem mapeamento.
  enum mapped_status: { open: 0, resolved: 1, pending: 2, snoozed: 3 }, _prefix: :mapped

  validates :name, presence: { message: I18n.t('errors.validations.presence') }
  validates :mapped_status, uniqueness: { scope: :pipeline_id }, allow_nil: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :color, presence: true

  delegate :account, to: :pipeline
end
