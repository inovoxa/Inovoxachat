# == Schema Information
#
# Table name: glpi_account_configs
#
#  id            :bigint           not null, primary key
#  central_url   :string           (legado — não usado na conexão direta)
#  enabled       :boolean          default(FALSE), not null
#  secrets       :text             (cifrado: senhas de conexão)
#  service_token :text             (legado)
#  settings      :jsonb            not null (não-secretos de conexão)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#
# Configuração da integração GLPI de uma empresa (Account). Multi-tenant: o Chatwoot
# conecta DIRETO ao GLPI/PostgreSQL/AD da empresa usando estas variáveis.
class GlpiAccountConfig < ApplicationRecord
  belongs_to :account

  serialize :secrets, coder: JSON
  encrypts :secrets

  validates :account_id, uniqueness: true

  # Valores não-secretos pré-preenchidos (Prefeitura de Araraquara). Editáveis na tela.
  DEFAULT_SETTINGS = {
    'GLPI_DB_HOST' => '187.32.171.151',
    'GLPI_DB_PORT' => '3306',
    'GLPI_DB_USER' => 'qtszs1qRYvTW5lKR',
    'GLPI_DB_DATABASE' => 'glpi-db',
    'GLPI_API_V1_URL' => 'https://suporte.araraquara.sp.gov.br/api.php/v1',
    'PG_HOST' => 'e8w8400k0wc0gksos8okwgwg',
    'PG_PORT' => '5432',
    'PG_USER' => 'postgres',
    'PG_DATABASE' => 'Prefeitura_Municipal_de_Araraquara',
    'PG_SCHEMA' => 'glpi_n8n',
    'AD_SSH_HOST' => '187.32.171.139',
    'AD_SSH_PORT' => '22',
    'AD_SSH_USER' => 'pma\\lgti.fmiguel',
    'AD_SCRIPT_PATH' => 'C:\\Scripts\\Coletar_Auditoria_AD.ps1',
    'AD_APROVADORES_SCRIPT' => 'C:\\Scripts\\Gerenciar_Aprovadores.ps1',
    'AD_COLLECTOR_CRON' => '*/5 * * * *',
    'AGENTE_MIN_POR_OP' => '25',
    'AGENTE_CUSTO_HORA' => '30',
  }.freeze

  # Segredos: nunca no código/Git. Pré-preenchem via ENV do deploy ou digitados na tela.
  SECRET_KEYS = %w[GLPI_DB_PASSWORD PG_PASSWORD AD_SSH_PASSWORD].freeze

  # Conta "modelo" (Prefeitura) que recebe os DEFAULT_SETTINGS pré-preenchidos, definida por
  # ENV GLPI_DEFAULT_ACCOUNT_ID. ISOLAMENTO: qualquer outra empresa NÃO herda nada da Prefeitura.
  def self.default_account_id
    ENV['GLPI_DEFAULT_ACCOUNT_ID'].presence
  end

  def default_account?
    self.class.default_account_id.present? && account_id.to_s == self.class.default_account_id.to_s
  end

  # Settings efetivos: SÓ os valores salvos desta empresa. Os DEFAULT_SETTINGS entram apenas
  # para a conta-modelo (Prefeitura) — nunca vazam para outras empresas.
  def effective_settings
    base = default_account? ? DEFAULT_SETTINGS : {}
    base.merge(settings || {})
  end

  # Segredo: salvo (cifrado) desta empresa; fallback de ENV só para a conta-modelo.
  def secret(key)
    saved = secrets && secrets[key].presence
    return saved if saved
    return ENV["GLPI_DEFAULT_#{key}"].presence if default_account?

    nil
  end

  def secret_present?(key)
    secret(key).present?
  end

  def usable?
    enabled?
  end
end
