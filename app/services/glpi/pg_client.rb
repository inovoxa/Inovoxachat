require 'pg'

module Glpi
  # Conexão de leitura ao PostgreSQL do n8n da empresa (schema glpi_n8n: chamados_log, etc.).
  # Credenciais vêm de GlpiAccountConfig (multi-empresa). Use e feche por request.
  class PgClient
    SCHEMA_RE = /\A[a-zA-Z0-9_]+\z/

    def initialize(cfg)
      s = cfg.effective_settings
      @schema = s['PG_SCHEMA'].to_s
      @schema = 'glpi_n8n' unless @schema.match?(SCHEMA_RE)
      @conn = PG.connect(
        host: s['PG_HOST'],
        port: (s['PG_PORT'].presence || 5432).to_i,
        dbname: s['PG_DATABASE'],
        user: s['PG_USER'],
        password: cfg.secret('PG_PASSWORD'),
        connect_timeout: 6
      )
    end

    # {s} no SQL é substituído pelo schema (validado) da empresa.
    def query(sql, params = [])
      @conn.exec_params(sql.gsub('{s}', @schema), params).to_a
    end

    def close
      @conn&.close
    rescue StandardError
      nil
    end
  end
end
