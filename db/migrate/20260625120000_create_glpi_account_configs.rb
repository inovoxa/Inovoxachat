# Integração GLPI por-account (multi-empresa). Cada Account aponta para a sua
# Central de Operações GLPI (Fastify). O service_token é cifrado em repouso.
class CreateGlpiAccountConfigs < ActiveRecord::Migration[7.0]
  def change
    create_table :glpi_account_configs do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.boolean :enabled, null: false, default: false
      t.string :central_url
      t.text :service_token # cifrado em repouso via ActiveRecord encryption

      t.timestamps
    end
  end
end
