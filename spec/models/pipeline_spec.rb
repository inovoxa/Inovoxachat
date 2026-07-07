require 'rails_helper'

RSpec.describe Pipeline do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:pipeline_stages).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }

    it 'rejects an unknown template_key' do
      pipeline = FactoryBot.build(:pipeline, template_key: 'nao_existe')
      expect(pipeline.valid?).to be false
    end

    it 'allows a blank template_key' do
      pipeline = FactoryBot.build(:pipeline, template_key: nil)
      expect(pipeline.valid?).to be true
    end
  end

  describe 'creation from template' do
    it 'seeds the suporte template stages in order' do
      pipeline = create(:pipeline, template_key: 'suporte')

      expect(pipeline.pipeline_stages.map(&:name)).to eq(
        ['Novo', 'Em Atendimento', 'Aguardando Cliente', 'Resolvido', 'Fechado']
      )
      expect(pipeline.pipeline_stages.map(&:position)).to eq([1, 2, 3, 4, 5])
    end

    it 'seeds the vendas template stages' do
      pipeline = create(:pipeline, template_key: 'vendas')

      expect(pipeline.pipeline_stages.map(&:name)).to eq(
        ['Lead', 'Qualificação', 'Proposta', 'Negociação', 'Ganho/Perdido']
      )
    end

    it 'seeds a single starting stage without a template' do
      pipeline = create(:pipeline)

      expect(pipeline.pipeline_stages.map(&:name)).to eq(['Início'])
    end
  end

  describe '.entry_stage_for' do
    let(:account) { create(:account) }

    it 'returns nil when no pipeline has the mode enabled' do
      create(:pipeline, account: account, auto_add_mode: :disabled)

      expect(described_class.entry_stage_for(account, :new_conversations)).to be_nil
    end

    it 'returns the first stage of the pipeline with the mode enabled' do
      pipeline = create(:pipeline, account: account, template_key: 'suporte', auto_add_mode: :new_conversations)

      expect(described_class.entry_stage_for(account, :new_conversations)).to eq(pipeline.pipeline_stages.first)
    end
  end

  describe 'automatic entry on the first stage' do
    let(:account) { create(:account) }

    it 'assigns a new conversation when auto_add_mode is new_conversations' do
      pipeline = create(:pipeline, account: account, template_key: 'suporte', auto_add_mode: :new_conversations)
      conversation = create(:conversation, account: account)

      expect(conversation.reload.pipeline_stage).to eq(pipeline.pipeline_stages.first)
    end

    it 'does not assign a new conversation when auto_add_mode is disabled' do
      create(:pipeline, account: account, template_key: 'suporte', auto_add_mode: :disabled)
      conversation = create(:conversation, account: account)

      expect(conversation.reload.pipeline_stage).to be_nil
    end

    it 'assigns a new contact when auto_add_mode is new_contacts' do
      pipeline = create(:pipeline, account: account, template_key: 'vendas', auto_add_mode: :new_contacts)
      contact = create(:contact, account: account)

      expect(contact.reload.pipeline_stage).to eq(pipeline.pipeline_stages.first)
    end
  end

  describe 'backfill on enabling the mode' do
    let(:account) { create(:account) }

    it 'backfills recent unstaged conversations when the mode is turned on' do
      pipeline = create(:pipeline, account: account, template_key: 'suporte', auto_add_mode: :disabled)
      conversation = create(:conversation, account: account)
      expect(conversation.reload.pipeline_stage).to be_nil

      pipeline.update!(auto_add_mode: :new_conversations)

      expect(conversation.reload.pipeline_stage).to eq(pipeline.pipeline_stages.first)
    end

    it 'does not touch conversations already in a stage' do
      pipeline = create(:pipeline, account: account, template_key: 'suporte', auto_add_mode: :disabled)
      other_stage = pipeline.pipeline_stages.second
      conversation = create(:conversation, account: account)
      conversation.update!(pipeline_stage: other_stage)

      pipeline.update!(auto_add_mode: :new_conversations)

      expect(conversation.reload.pipeline_stage).to eq(other_stage)
    end
  end

  describe 'account association' do
    it 'exposes pipeline_stages through pipelines' do
      account = create(:account)
      pipeline = create(:pipeline, account: account, template_key: 'generico')

      expect(account.pipeline_stages).to match_array(pipeline.pipeline_stages)
    end
  end
end
