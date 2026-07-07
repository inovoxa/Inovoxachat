class CreatePipelines < ActiveRecord::Migration[7.1]
  def change
    create_table :pipelines do |t|
      t.references :account, null: false, index: true
      t.string :name, null: false
      t.text :description
      t.string :template_key
      # 0=disabled | 1=new_conversations | 2=new_contacts (ver enum em Pipeline)
      t.integer :auto_add_mode, null: false, default: 0

      t.timestamps
    end
  end
end
