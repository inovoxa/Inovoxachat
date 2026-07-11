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

  # Chaves de settings não-secretos aceitas (whitelist) + dicas de preenchimento
  # genéricas para a tela. NÃO contém dados reais de nenhuma empresa: valores de
  # host/usuário/database/URL/caminho ficam vazios (cada conta digita os seus).
  # Apenas defaults universais e inofensivos (portas, cron, nome padrão do OCS)
  # são pré-preenchidos. Assim a tela de uma empresa nunca expõe a infra de outra.
  SUGGESTED_SETTINGS = {
    'GLPI_DB_HOST' => '',
    'GLPI_DB_PORT' => '3306',
    'GLPI_DB_USER' => '',
    'GLPI_DB_DATABASE' => '',
    'GLPI_API_V1_URL' => '',
    'PG_HOST' => '',
    'PG_PORT' => '5432',
    'PG_USER' => '',
    'PG_DATABASE' => '',
    'PG_SCHEMA' => '',
    'AD_SSH_HOST' => '',
    'AD_SSH_PORT' => '22',
    'AD_SSH_USER' => '',
    'AD_SCRIPT_PATH' => '',
    'AD_APROVADORES_SCRIPT' => '',
    'AD_COLLECTOR_CRON' => '*/5 * * * *',
    'AGENTE_MIN_POR_OP' => '',
    'AGENTE_CUSTO_HORA' => '',
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
