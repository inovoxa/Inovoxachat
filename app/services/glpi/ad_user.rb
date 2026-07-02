module Glpi
  # Consulta um usuário no Active Directory via SSH → Coletar_Auditoria_AD.ps1 -User <login>.
  # Read-only. Reutilizado pelo endpoint (tela) e pela tool do Copilot.
  class AdUser
    SAFE_LOGIN = /\A[A-Za-z0-9._\-\\ ]{1,128}\z/

    def initialize(cfg)
      @cfg = cfg
    end

    # Retorna um Hash com os dados do usuário (login, nome, grupos, datas, status, OU, etc.).
    # Levanta com mensagem clara se o login for inválido ou o AD devolver { erro }.
    def lookup(login)
      login = login.to_s.strip
      raise 'login inválido' unless login.match?(SAFE_LOGIN)

      script = @cfg.effective_settings['AD_SCRIPT_PATH'].presence || 'C:\\Scripts\\Coletar_Auditoria_AD.ps1'
      cmd = %(powershell -NoProfile -ExecutionPolicy Bypass -File "#{script}" -User "#{login.delete('"')}")
      parse(Glpi::SshClient.new(@cfg).run(cmd))
    end

    private

    def parse(raw)
      obj = JSON.parse(raw.to_s.strip)
      raise obj['erro'] if obj.is_a?(Hash) && obj['erro'].present?

      obj
    rescue JSON::ParserError
      raise 'resposta inválida do AD'
    end
  end
end
