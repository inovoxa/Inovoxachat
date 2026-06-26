# Visão Geral: KPIs de chamados (MySQL GLPI) + execuções/canais (PostgreSQL n8n).
# Sem auditoria de usuário (logon/bloqueio do AD) — escopo definido pelo produto.
class Api::V1::Accounts::Glpi::OverviewController < Api::V1::Accounts::Glpi::BaseController
  DAYS = { '7d' => 7, '30d' => 30, '90d' => 90, '180d' => 180 }.freeze

  # GET /api/v1/accounts/:account_id/glpi/overview?period=180d
  def show
    period = DAYS.key?(params[:period]) ? params[:period] : '180d'
    desde_my = (Time.current - DAYS[period].days).strftime('%Y-%m-%d %H:%M:%S')
    start_iso = (Time.current - DAYS[period].days).utc.iso8601

    counts = ticket_counts(desde_my)
    exec_ad, semanal = pg_metrics(start_iso)

    render json: {
      period: period,
      cards: {
        total: counts['total'].to_i,
        abertos: counts['abertos'].to_i,
        resolvidos: counts['resolvidos'].to_i,
        execucoesAD: exec_ad
      },
      semanal: semanal,
      generatedAt: Time.current.iso8601
    }
  rescue Mysql2::Error, PG::Error => e
    render json: { error: 'falha ao montar a visão geral', detail: e.message }, status: :bad_gateway
  end

  private

  def ticket_counts(desde_my)
    my = Glpi::MysqlClient.new(glpi_config)
    my.query(<<~SQL).first || {}
      SELECT COUNT(*) AS total,
             SUM(status IN (1, 2, 3, 4)) AS abertos,
             SUM(status IN (5, 6)) AS resolvidos
        FROM glpi_tickets
       WHERE is_deleted = 0 AND date >= '#{my.escape(desde_my)}'
    SQL
  ensure
    my&.close
  end

  def pg_metrics(start_iso)
    pg = Glpi::PgClient.new(glpi_config)
    e = pg.query('SELECT COUNT(*)::int AS c FROM {s}.chamados_log WHERE ad_executado AND ad_executado_em >= $1', [start_iso]).first
    [e['c'].to_i, weekly_channel(pg)]
  ensure
    pg&.close
  end

  def weekly_channel(pg)
    rows = pg.query(<<~SQL)
      SELECT FLOOR(EXTRACT(EPOCH FROM (now() - created_at)) / 604800)::int AS wk,
             COUNT(*) FILTER (WHERE conversa_id IS NOT NULL) AS wa,
             COUNT(*) FILTER (WHERE conversa_id IS NULL) AS form
        FROM {s}.chamados_log
       WHERE created_at >= now() - interval '28 days'
       GROUP BY wk
    SQL
    wa = [0, 0, 0, 0]
    form = [0, 0, 0, 0]
    rows.each do |x|
      w = x['wk'].to_i
      next unless w.between?(0, 3)

      wa[w] = x['wa'].to_i
      form[w] = x['form'].to_i
    end
    idx = [3, 2, 1, 0] # S1 (mais antiga) .. S4 (atual)
    { labels: %w[S1 S2 S3 S4], whatsapp: idx.map { |w| wa[w] }, formulario: idx.map { |w| form[w] } }
  end
end
