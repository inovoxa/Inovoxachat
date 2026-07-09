# == Schema Information
#
# Table name: calendar_connections
#
#  id                         :bigint           not null, primary key
#  access_token               :text
#  expires_at                 :datetime
#  external_calendar_id       :string
#  last_synced_at             :datetime
#  provider                   :integer          not null
#  refresh_token              :text
#  sync_enabled               :boolean          default(TRUE), not null
#  sync_token                 :text
#  webhook_channel_id         :string
#  webhook_expires_at         :datetime
#  webhook_resource_id        :string
#  webhook_subscription_id    :string
#  webhook_verification_token :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  account_id                 :bigint           not null
#  user_id                    :bigint           not null
#
# Indexes
#
#  index_calendar_connections_on_account_id               (account_id)
#  index_calendar_connections_on_user_id                  (user_id)
#  index_calendar_connections_on_user_id_and_provider     (user_id,provider) UNIQUE
#  index_calendar_connections_on_webhook_channel_id       (webhook_channel_id)
#  index_calendar_connections_on_webhook_subscription_id  (webhook_subscription_id)
#
class CalendarConnection < ApplicationRecord
  belongs_to :account
  belongs_to :user

  # Tokens em repouso cifrados quando a instância tem ACTIVE_RECORD_ENCRYPTION_*;
  # sem isso ficam em claro — a conexão loga um warning (ver callback abaixo).
  if Chatwoot.encryption_configured?
    encrypts :access_token
    encrypts :refresh_token
  end

  enum provider: { google: 0, outlook: 1 }

  validates :provider, presence: true
  validates :provider, uniqueness: { scope: :user_id }

  scope :sync_enabled, -> { where(sync_enabled: true) }

  after_create :warn_if_unencrypted

  def token_expired?
    return true if expires_at.blank?

    # Janela de 5 minutos para evitar corrida entre o check e o uso do token.
    Time.current >= expires_at - 5.minutes
  end

  # Eventos internos do dono desta conexão, candidatos a push para o provedor.
  def pushable_events
    account.calendar_events.where(user_id: user_id, source: :internal)
  end

  private

  def warn_if_unencrypted
    return if Chatwoot.encryption_configured?

    Rails.logger.warn("[CalendarConnection] #{id}: ACTIVE_RECORD_ENCRYPTION nao configurado - tokens OAuth armazenados em claro")
  end
end
