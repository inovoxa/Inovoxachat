# == Schema Information
#
# Table name: pipelines
#
#  id            :bigint           not null, primary key
#  auto_add_mode :integer          default("disabled"), not null
#  description   :text
#  name          :string           not null
#  template_key  :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#
# Indexes
#
#  index_pipelines_on_account_id  (account_id)
#
class Pipeline < ApplicationRecord
  belongs_to :account

  has_many :pipeline_stages, -> { order(:position) }, dependent: :destroy, inverse_of: :pipeline

  # Entrada automática no primeiro estágio do pipeline:
  # disabled          -> nada entra automaticamente
  # new_conversations -> toda conversa nova da conta entra no estágio 1
  # new_contacts      -> todo contato novo da conta entra no estágio 1
  enum auto_add_mode: { disabled: 0, new_conversations: 1, new_contacts: 2 }

  validates :name, presence: { message: I18n.t('errors.validations.presence') }
  validates :template_key, inclusion: { in: PipelineTemplates.keys }, allow_blank: true

  after_create :seed_stages_from_template

  # Primeiro estágio do primeiro pipeline da conta configurado com o modo dado.
  def self.entry_stage_for(account, mode)
    account.pipelines.where(auto_add_mode: mode).order(:id).each do |pipeline|
      stage = pipeline.pipeline_stages.first
      return stage if stage
    end
    nil
  end

  private

  def seed_stages_from_template
    PipelineTemplates.stages_for(template_key).each_with_index do |stage, index|
      pipeline_stages.create!(name: stage[:name], color: stage[:color], position: index + 1)
    end
  end
end
