require 'mysql2'

module Glpi
  # Conexão de leitura a um MySQL da empresa. Credenciais de GlpiAccountConfig.
  # `prefix` escolhe o conjunto de variáveis: 'GLPI_DB' (padrão) ou 'OCS_DB' (OCS Inventory).
  # Use e feche por request.
  class MysqlClient
    def initialize(cfg, prefix: 'GLPI_DB')
      s = cfg.effective_settings
      @client = Mysql2::Client.new(
        host: s["#{prefix}_HOST"],
        port: (s["#{prefix}_PORT"].presence || 3306).to_i,
        username: s["#{prefix}_USER"],
        password: cfg.secret("#{prefix}_PASSWORD"),
        database: s["#{prefix}_DATABASE"],
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
