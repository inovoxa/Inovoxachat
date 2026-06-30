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

  # Sugestões de preenchimento (apenas placeholder na tela). NÃO são herdadas: cada empresa
  # salva seus próprios valores. Servem só para facilitar o cadastro da Prefeitura.
  SUGGESTED_SETTINGS = {
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
    'OCS_DB_HOST' => '',
    'OCS_DB_PORT' => '3306',
    'OCS_DB_USER' => '',
    'OCS_DB_DATABASE' => 'ocsweb',
  }.freeze

  # Segredos: nunca no código/Git. Digitados na tela (cifrados em repouso).
  SECRET_KEYS = %w[
    GLPI_DB_PASSWORD PG_PASSWORD AD_SSH_PASSWORD
    GLPI_APP_TOKEN GLPI_USER_TOKEN
    GLPI_OAUTH_CLIENT_ID GLPI_OAUTH_CLIENT_SECRET
    OCS_DB_PASSWORD
  ].freeze

  # Settings efetivos: SÓ os valores salvos desta empresa (sem herança entre contas).
  def effective_settings
    settings || {}
  end

  # Segredo: apenas o salvo (cifrado) desta empresa.
  def secret(key)
    secrets && secrets[key].presence
  end

  def secret_present?(key)
    secret(key).present?
  end

  def usable?
    enabled?
  end
end
