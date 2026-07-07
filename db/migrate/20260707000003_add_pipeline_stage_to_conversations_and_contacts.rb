class AddPipelineStageToConversationsAndContacts < ActiveRecord::Migration[7.1]
  def change
    add_reference :conversations, :pipeline_stage, index: true
    add_reference :contacts, :pipeline_stage, index: true
  end
end
