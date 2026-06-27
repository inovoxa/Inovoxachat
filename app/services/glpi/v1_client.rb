require 'faraday'
require 'json'

module Glpi
  # Write-back de status via API REST v1 do GLPI. Porta backend/src/glpi/v1.js.
  # Tokens (App-Token/user_token) vêm do glpi_token_cache (PostgreSQL n8n da empresa).
  class V1Client
    def initialize(cfg, pg)
      @base = cfg.effective_settings['GLPI_API_V1_URL'].to_s.gsub(%r{/+\z}, '')
      app = cfg.secret('GLPI_APP_TOKEN')
      user = cfg.secret('GLPI_USER_TOKEN')

      if app.blank? || user.blank?
        # Fallback: tokens do glpi_token_cache (compatível com a Central/n8n).
        row = pg.query('SELECT app_token, user_token FROM {s}.glpi_token_cache WHERE id = 1').first
        app = app.presence || (row && row['app_token'])
        user = user.presence || (row && row['user_token'])
      end
      raise 'tokens da API v1 ausentes (defina App-Token/User-Token na Configuração ou no glpi_token_cache)' if app.blank? || user.blank?

      @app_token = app
      @user_token = user
    end

    def update_ticket_status(ticket_id, status)
      session = init_session
      res = conn.put("#{@base}/Ticket/#{ticket_id.to_i}") do |req|
        req.headers['App-Token'] = @app_token
        req.headers['Session-Token'] = session
        req.headers['Content-Type'] = 'application/json'
        req.body = { input: { id: ticket_id.to_i, status: status.to_i } }.to_json
      end
      raise "PUT /Ticket falhou (#{res.status})" unless res.success?

      true
    ensure
      kill_session(session) if session
    end

    private

    def conn
      @conn ||= Faraday.new do |f|
        f.options.timeout = 20
        f.options.open_timeout = 6
      end
    end

    def init_session
      res = conn.get("#{@base}/initSession") do |req|
        req.headers['App-Token'] = @app_token
        req.headers['Authorization'] = "user_token #{@user_token}"
      end
      body = (JSON.parse(res.body) rescue {})
      raise "initSession falhou (#{res.status})" unless res.success? && body['session_token']

      body['session_token']
    end

    def kill_session(token)
      conn.get("#{@base}/killSession") do |req|
        req.headers['App-Token'] = @app_token
        req.headers['Session-Token'] = token
      end
    rescue StandardError
      nil
    end
  end
end
