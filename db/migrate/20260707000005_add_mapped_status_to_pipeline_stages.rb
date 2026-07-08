class AddMappedStatusToPipelineStages < ActiveRecord::Migration[7.1]
  def change
    # Mapeia um estágio a um status de conversa (open/resolved/pending/snoozed).
    # Quando a conversa muda para esse status, o card vai para este estágio.
    add_column :pipeline_stages, :mapped_status, :integer
  end
end
