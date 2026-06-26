require 'net/ssh'

module Glpi
  # Execução de comandos no Domain Controller via SSH (AD da empresa).
  # Credenciais de GlpiAccountConfig (AD_SSH_*). Porta backend/src/ad/ssh.js.
  class SshClient
    def initialize(cfg)
      s = cfg.effective_settings
      @host = s['AD_SSH_HOST']
      @port = (s['AD_SSH_PORT'].presence || 22).to_i
      @user = normalize_user(s['AD_SSH_USER'])
      @password = cfg.secret('AD_SSH_PASSWORD')
      raise 'AD/SSH não configurado (defina AD_SSH_*)' if @host.blank? || @user.blank?
    end

    # Roda um comando e devolve a stdout (string).
    def run(command)
      out = +''
      Net::SSH.start(
        @host, @user,
        password: @password,
        port: @port,
        timeout: 15,
        non_interactive: true,
        number_of_password_prompts: 1
      ) do |ssh|
        out << ssh.exec!(command).to_s
      end
      out
    end

    private

    # Colapsa barras invertidas duplicadas (DOMINIO\\user -> DOMINIO\user); alguns ambientes
    # (ex.: Coolify) dobram a "\" ao injetar a variável e isso quebra o login.
    def normalize_user(user)
      user.to_s.gsub(/\\+/) { '\\' }.strip
    end
  end
end
