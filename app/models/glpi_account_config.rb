# == Schema Information
#
# Table name: glpi_account_configs
#
#  id            :bigint           not null, primary key
#  central_url   :string
#  enabled       :boolean          default(FALSE), not null
#  service_token :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#
# Configuração da integração GLPI de uma empresa (Account). Multi-tenant:
# cada Account tem no máximo uma config, apontando para a sua Central GLPI.
class GlpiAccountConfig < ApplicationRecord
  belongs_to :account

  encrypts :service_token

  validates :account_id, uniqueness: true
  validates :central_url, presence: true, if: :enabled?

  # Normaliza a URL da Central (sem barra final) para o proxy montar os caminhos.
  def normalized_central_url
    central_url.to_s.gsub(%r{/+\z}, '')
  end

  def usable?
    enabled? && central_url.present?
  end
end
