class CreatePipelineStages < ActiveRecord::Migration[7.1]
  def change
    create_table :pipeline_stages do |t|
      t.references :pipeline, null: false, index: true
      t.string :name, null: false
      t.integer :position, null: false, default: 1
      t.string :color, null: false, default: '#1F93FF'

      t.timestamps
    end

    add_index :pipeline_stages, [:pipeline_id, :position]
  end
end
