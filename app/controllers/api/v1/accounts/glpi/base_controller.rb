# Base do módulo GLPI: resolve a config da conta (multi-empresa) e faz o proxy
# server-side para a Central de Operações GLPI daquela conta (Fastify).
class Api::V1::Accounts::Glpi::BaseController < Api::V1::Accounts::BaseController
  before_action :ensure_glpi_enabled

  private

  def glpi_config
    @glpi_config ||= GlpiAccountConfig.find_by(account_id: current_account.id)
  end

  def ensure_glpi_enabled
    return if glpi_config&.usable?

    render json: { error: 'integração GLPI não configurada para esta conta' }, status: :not_found
  end

  # Repassa a requisição para a Central da conta corrente.
  # method: :get/:patch ; path: '/api/...' ; query: Hash ; body: Hash|nil
  def proxy_to_central(method, path, query: {}, body: nil)
    response = central_connection.run_request(method, path, body&.to_json, nil) do |req|
      req.params.update(query.compact_blank) if query.present?
    end
    render json: parse_body(response.body), status: response.status
  rescue Faraday::Error => e
    render json: { error: 'falha ao comunicar com a Central GLPI', detail: e.message },
           status: :bad_gateway
  end

  def central_connection
    @central_connection ||= Faraday.new(
      url: glpi_config.normalized_central_url,
      headers: central_headers
    ) do |f|
      f.options.timeout = 20
      f.options.open_timeout = 5
    end
  end

  # Token de serviço + identidade do usuário do Chatwoot (a Central aplica o RBAC).
  def central_headers
    {
      'Content-Type' => 'application/json',
      'X-Service-Token' => glpi_config.service_token.to_s,
      'X-User-Id' => Current.user&.id.to_s,
      'X-User-Email' => Current.user&.email.to_s,
      'X-User-Role' => glpi_role
    }
  end

  def glpi_role
    Current.account_user&.administrator? ? 'admin' : 'agent'
  end

  def parse_body(body)
    return body unless body.is_a?(String)

    JSON.parse(body)
  rescue JSON::ParserError
    body
  end
end
