require 'faraday'
require 'json'

module Glpi
  # Write-back de status via API v2 do GLPI (OAuth2, grant_type=password).
  # Credenciais (Cliente OAuth) vêm da config da empresa, com fallback para o glpi_token_cache
  # (mesmo que a Central/n8n usam). O caminho/persistência da v2 ainda varia entre versões do
  # GLPI; por isso o controller usa este client com fallback automático para a v1.
  class V2Client
    def initialize(cfg, pg)
      @creds = oauth_creds(cfg, pg)
      raise 'Cliente OAuth ausente (client_id/secret) e sem token_url' if @creds[:client_id].blank? || @creds[:token_url].blank?

      @token_url = @creds[:token_url]
      @base = @token_url.sub(%r{/token/?\z}, '') # .../api.php/v2.3
    end

    def update_ticket_status(ticket_id, status)
      res = conn.patch("#{@base}/Assistance/Ticket/#{ticket_id.to_i}") do |req|
        req.headers['Authorization'] = "Bearer #{access_token}"
        req.headers['Content-Type'] = 'application/json'
        req.body = { status: status.to_i }.to_json
      end
      raise "PATCH v2 falhou (#{res.status}): #{res.body}" unless res.success?

      true
    end

    private

    def conn
      @conn ||= Faraday.new do |f|
        f.options.timeout = 20
        f.options.open_timeout = 6
      end
    end

    def access_token
      res = conn.post(@token_url) do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = {
          grant_type: 'password',
          client_id: @creds[:client_id],
          client_secret: @creds[:client_secret],
          username: @creds[:username],
          password: @creds[:password],
          scope: ''
        }.to_json
      end
      body = (JSON.parse(res.body) rescue {})
      raise "token v2 falhou (#{res.status})" unless res.success? && body['access_token']

      body['access_token']
    end

    def oauth_creds(cfg, pg)
      row = begin
        pg.query('SELECT client_id, client_secret, glpi_username, glpi_password, token_url FROM {s}.glpi_token_cache WHERE id = 1').first || {}
      rescue StandardError
        {}
      end
      {
        client_id: cfg.secret('GLPI_OAUTH_CLIENT_ID').presence || row['client_id'].presence,
        client_secret: cfg.secret('GLPI_OAUTH_CLIENT_SECRET').presence || row['client_secret'].presence,
        username: row['glpi_username'].presence,
        password: row['glpi_password'].presence,
        token_url: row['token_url'].presence
      }
    end
  end
end
