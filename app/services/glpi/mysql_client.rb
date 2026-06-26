require 'mysql2'

module Glpi
  # Conexão de leitura ao MySQL do GLPI da empresa. Credenciais de GlpiAccountConfig.
  # Use e feche por request.
  class MysqlClient
    def initialize(cfg)
      s = cfg.effective_settings
      @client = Mysql2::Client.new(
        host: s['GLPI_DB_HOST'],
        port: (s['GLPI_DB_PORT'].presence || 3306).to_i,
        username: s['GLPI_DB_USER'],
        password: cfg.secret('GLPI_DB_PASSWORD'),
        database: s['GLPI_DB_DATABASE'],
        connect_timeout: 6,
        reconnect: false
      )
    end

    def query(sql)
      @client.query(sql, as: :hash).to_a
    end

    def escape(value)
      @client.escape(value.to_s)
    end

    def close
      @client&.close
    rescue StandardError
      nil
    end
  end
end
