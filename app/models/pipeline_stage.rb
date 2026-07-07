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

  validates :name, presence: { message: I18n.t('errors.validations.presence') }
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :color, presence: true

  delegate :account, to: :pipeline
end
