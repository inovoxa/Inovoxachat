# Visão Geral: KPIs de chamados (MySQL GLPI) + execuções/canais (PostgreSQL n8n).
# Sem auditoria de usuário (logon/bloqueio do AD) — escopo definido pelo produto.
class Api::V1::Accounts::Glpi::OverviewController < Api::V1::Accounts::Glpi::BaseController
  # GET /api/v1/accounts/:account_id/glpi/overview?period=180d  (ou ?from=&to=)
  def show
    from, to = date_range
    from_my = from.strftime('%Y-%m-%d %H:%M:%S')
    to_my = to.strftime('%Y-%m-%d %H:%M:%S')
    from_iso = from.utc.iso8601
    to_iso = to.utc.iso8601

    mysql = ticket_mysql(from_my, to_my)
    exec_ad, semanal = pg_metrics(from_iso, to_iso)
    counts = mysql[:counts]

    render json: {
      cards: {
        total: counts['total'].to_i,
        abertos: counts['abertos'].to_i,
        resolvidos: counts['resolvidos'].to_i,
        execucoesAD: exec_ad
      },
      semanal: semanal,
      categorias: mysql[:categorias],
      generatedAt: Time.current.iso8601
    }
  rescue Mysql2::Error, PG::Error => e
    render json: { error: 'falha ao montar a visão geral', detail: e.message }, status: :bad_gateway
  end

  private

  def ticket_mysql(from_my, to_my)
    my = Glpi::MysqlClient.new(glpi_config)
    f_esc = my.escape(from_my)
    t_esc = my.escape(to_my)
    counts = my.query(<<~SQL).first || {}
      SELECT COUNT(*) AS total,
             SUM(status IN (1, 2, 3, 4)) AS abertos,
             SUM(status IN (5, 6)) AS resolvidos
        FROM glpi_tickets
       WHERE is_deleted = 0 AND date >= '#{f_esc}' AND date <= '#{t_esc}'
    SQL
    cats = my.query(<<~SQL)
      SELECT COALESCE(c.completename, 'Sem categoria') AS cat, COUNT(*) AS total
        FROM glpi_tickets t
        LEFT JOIN glpi_itilcategories c ON c.id = t.itilcategories_id
       WHERE t.is_deleted = 0 AND t.date >= '#{f_esc}' AND t.date <= '#{t_esc}'
       GROUP BY cat ORDER BY total DESC LIMIT 6
    SQL
    {
      counts: counts,
      categorias: { labels: cats.map { |x| short_cat(x['cat']) }, data: cats.map { |x| x['total'].to_i } }
    }
  ensure
    my&.close
  end

  def short_cat(cat)
    cat.to_s.split('>').last.to_s.strip.presence || 'Sem categoria'
  end

  def pg_metrics(from_iso, to_iso)
    pg = Glpi::PgClient.new(glpi_config)
    e = pg.query('SELECT COUNT(*)::int AS c FROM {s}.chamados_log WHERE ad_executado AND ad_executado_em >= $1 AND ad_executado_em <= $2', [from_iso, to_iso]).first
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
