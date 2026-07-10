class AddLastSyncErrorToCalendarConnections < ActiveRecord::Migration[7.1]
  def change
    # Última falha de sincronização, exibida na tela de integrações para
    # diagnóstico (limpa a cada sync bem-sucedido).
    add_column :calendar_connections, :last_sync_error, :text
  end
end
