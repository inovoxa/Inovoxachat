# Configuração da integração GLPI por conta (multi-empresa).
# show/status: usuário autenticado. update: somente admin.
# settings = não-secretos (jsonb). SUGGESTED_SETTINGS vai à tela só como placeholder.
# secrets  = senhas (cifradas; nunca devolvidas — só a flag de presença).
class Api::V1::Accounts::Glpi::ConfigsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?, only: [:update, :test]

  # GET /api/v1/accounts/:account_id/glpi/config
  def show
    render json: serialize(find_or_build)
  end

  # PATCH /api/v1/accounts/:account_id/glpi/config
  def update
    # enabled é controlado pelo super admin (/super_admin/accounts) — não pela empresa.
    cfg = find_or_build

    incoming = (config_params[:settings] || {}).to_h.slice(*GlpiAccountConfig::SUGGESTED_SETTINGS.keys)
    cfg.settings = (cfg.settings || {}).merge(incoming)

    sec_in = (config_params[:secrets] || {}).to_h
    merged = cfg.secrets || {}
    GlpiAccountConfig::SECRET_KEYS.each { |k| merged[k] = sec_in[k] if sec_in[k].present? }
    cfg.secrets = merged

    cfg.save!
    render json: serialize(cfg)
  end

  # GET /api/v1/accounts/:account_id/glpi/config/status  (usado pelo menu)
  def status
    cfg = GlpiAccountConfig.find_by(account_id: current_account.id)
    render json: { enabled: cfg&.usable? || false }
  end

  # GET /api/v1/accounts/:account_id/glpi/config/test  (testa cada conexão)
  def test
    cfg = find_or_build
    render json: {
      postgres: probe { c = Glpi::PgClient.new(cfg); c.query('SELECT 1'); c.close },
      mysql: probe { m = Glpi::MysqlClient.new(cfg); m.query('SELECT 1'); m.close },
      ssh: probe { Glpi::SshClient.new(cfg).run('echo ok') }
    }
  end

  private

  def probe
    yield
    { ok: true }
  rescue StandardError => e
    { ok: false, detail: e.message }
  end

  def find_or_build
    GlpiAccountConfig.find_or_initialize_by(account_id: current_account.id)
  end

  def config_params
    params.require(:config).permit(settings: {}, secrets: {})
  end

  def serialize(cfg)
    {
      enabled: cfg.enabled,
      settings: cfg.effective_settings,
      suggestions: GlpiAccountConfig::SUGGESTED_SETTINGS,
      secret_keys: GlpiAccountConfig::SECRET_KEYS,
      secrets_present: GlpiAccountConfig::SECRET_KEYS.index_with { |k| cfg.secret_present?(k) },
    }
  end
end
