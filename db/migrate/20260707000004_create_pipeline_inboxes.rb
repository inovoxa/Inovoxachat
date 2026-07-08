class CreatePipelineInboxes < ActiveRecord::Migration[7.1]
  def change
    create_table :pipeline_inboxes do |t|
      t.references :pipeline, null: false, index: true
      t.references :inbox, null: false, index: true

      t.timestamps
    end

    add_index :pipeline_inboxes, [:pipeline_id, :inbox_id], unique: true
  end
end
