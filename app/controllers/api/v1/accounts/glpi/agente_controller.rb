# Agente IA: conexão DIRETA ao PostgreSQL do n8n (chamados_log + glpi_categorias).
# Porta a lógica de backend/src/db/agenteQueries.js + ROI de routes/agente.js.
class Api::V1::Accounts::Glpi::AgenteController < Api::V1::Accounts::Glpi::BaseController
  # GET /api/v1/accounts/:account_id/glpi/agente?period=180d  (ou ?from=&to=)
  def show
    from, to = date_range
    from_iso = from.utc.iso8601
    to_iso = to.utc.iso8601

    pg = Glpi::PgClient.new(glpi_config)
    begin
      ms = period_stats(pg, from_iso, to_iso)
      ops = operacoes(pg, from_iso, to_iso)
      diario = exec_diario(pg, from_iso, to_iso)
    ensure
      pg.close
    end

    s = glpi_config.effective_settings
    min_op = s['AGENTE_MIN_POR_OP'].to_i
    custo_h = s['AGENTE_CUSTO_HORA'].to_i
    horas = ((ms[:automated] * min_op) / 60.0).round
    sem_humano = ms[:total].positive? ? (ms[:automated] * 100.0 / ms[:total]).round : nil

    render json: {
      period: params[:period],
      cards: {
        conversas: ms[:conversas],
        semHumanoPct: sem_humano,
        tempoMedio: fmt_dur(ms[:avg_seg]),
        execucoesAD: ms[:automated],
      },
      operacoes: ops,
      roi: { horas: horas, economia: horas * custo_h, minPorOp: min_op, custoHora: custo_h },
      horasMensais: {
        labels: diario.map { |d| ddmm(d['dia']) },
        data: diario.map { |d| ((d['total'].to_i * min_op) / 60.0).round },
      },
      generatedAt: Time.current.iso8601,
    }
  rescue PG::Error => e
    render json: { error: 'falha ao consultar o PostgreSQL do n8n', detail: e.message }, status: :bad_gateway
  end

  private

  def period_stats(pg, from_iso, to_iso)
    sql = <<~SQL
      SELECT COUNT(*)::int AS total,
             COUNT(DISTINCT conversa_id)::int AS conversas,
             COUNT(*) FILTER (WHERE ad_executado)::int AS automated,
             AVG(EXTRACT(EPOCH FROM (ad_executado_em - created_at)))
               FILTER (WHERE ad_executado AND ad_executado_em IS NOT NULL AND created_at IS NOT NULL) AS avg_seg
        FROM {s}.chamados_log
       WHERE created_at >= $1 AND created_at <= $2
    SQL
    r = pg.query(sql, [from_iso, to_iso]).first || {}
    {
      total: r['total'].to_i,
      conversas: r['conversas'].to_i,
      automated: r['automated'].to_i,
      avg_seg: r['avg_seg'],
    }
  end

  def operacoes(pg, from_iso, to_iso)
    sql = <<~SQL
      SELECT COALESCE(cat.nome, 'Categoria ' || cl.glpi_category_id) AS nome, COUNT(*)::int AS total
        FROM {s}.chamados_log cl
        LEFT JOIN {s}.glpi_categorias cat ON cat.glpi_category_id = cl.glpi_category_id
       WHERE cl.created_at >= $1 AND cl.created_at <= $2
       GROUP BY 1 ORDER BY total DESC LIMIT 10
    SQL
    pg.query(sql, [from_iso, to_iso]).map { |x| { nome: x['nome'], total: x['total'].to_i } }
  end

  def exec_diario(pg, from_iso, to_iso)
    sql = <<~SQL
      SELECT to_char(date_trunc('day', ad_executado_em), 'YYYY-MM-DD') AS dia, COUNT(*)::int AS total
        FROM {s}.chamados_log
       WHERE ad_executado AND ad_executado_em >= $1 AND ad_executado_em <= $2
       GROUP BY dia ORDER BY dia
    SQL
    pg.query(sql, [from_iso, to_iso])
  end

  def fmt_dur(seg)
    return '—' if seg.nil?

    seg = seg.to_f
    return "#{(seg / 60).floor}m #{(seg % 60).round}s" if seg < 3600

    "#{(seg / 3600).floor}h #{((seg % 3600) / 60).round}m"
  end

  def ddmm(str)
    d = (Date.parse(str) rescue nil)
    d ? d.strftime('%d/%m') : str
  end
end
