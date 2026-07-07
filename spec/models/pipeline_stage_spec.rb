require 'rails_helper'

RSpec.describe PipelineStage do
  describe 'associations' do
    it { is_expected.to belong_to(:pipeline) }
    it { is_expected.to have_many(:conversations).dependent(:nullify) }
    it { is_expected.to have_many(:contacts).dependent(:nullify) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }

    it 'rejects a non positive position' do
      stage = FactoryBot.build(:pipeline_stage, position: 0)
      expect(stage.valid?).to be false
    end
  end

  describe 'destroy' do
    it 'nullifies the stage on associated conversations instead of deleting them' do
      account = create(:account)
      pipeline = create(:pipeline, account: account)
      stage = pipeline.pipeline_stages.first
      conversation = create(:conversation, account: account)
      conversation.update!(pipeline_stage: stage)

      stage.destroy!

      expect(conversation.reload.pipeline_stage_id).to be_nil
    end
  end
end
