# Tarefas de um projeto (Kanban por estágio). Reversível.
class CreateProjectTasks < ActiveRecord::Migration[7.1]
  def change
    create_table :project_tasks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.bigint :assignee_id
      t.string :title, null: false
      t.integer :stage, null: false, default: 0
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :project_tasks, [:project_id, :stage]
    add_index :project_tasks, :assignee_id
  end
end
