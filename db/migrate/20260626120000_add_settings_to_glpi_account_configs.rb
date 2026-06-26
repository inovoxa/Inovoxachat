# Config GLPI por empresa passa a guardar todas as variáveis de conexão:
# settings (não-secretos, jsonb) e secrets (senhas, cifrado em repouso).
class AddSettingsToGlpiAccountConfigs < ActiveRecord::Migration[7.0]
  def change
    add_column :glpi_account_configs, :settings, :jsonb, null: false, default: {}
    add_column :glpi_account_configs, :secrets, :text
  end
end
