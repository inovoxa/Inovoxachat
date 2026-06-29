# Atividade ao vivo: feed das execuções REAIS no AD (chamados_log.ad_executado).
# Conexão DIRETA ao PostgreSQL do n8n. Cada linha traz o detalhe de ad_resultado (JSONB)
# — a senha provisória NUNCA é exposta. Suporta filtros (período, tipo, resultado, busca)
# e é consumido em polling pela tela para dar sensação de tempo real.
class Api::V1::Accounts::Glpi::AtividadeController < Api::V1::Accounts::Glpi::BaseController
  LIMIT = 200
  # Chaves do ad_resultado que podem conter segredo e jamais devem sair na API.
  SECRET_RESULT_KEYS = %w[senha password senha_provisoria nova_senha].freeze

  # GET /api/v1/accounts/:account_id/glpi/atividade?period=90d&tipo=&resultado=&search=
  def show
    from, to = date_range
    pg = Glpi::PgClient.new(glpi_config)
    begin
      eventos = listar_eventos(pg, from.utc.iso8601, to.utc.iso8601)
      kpis = calcular_kpis(pg, from.utc.iso8601, to.utc.iso8601)
      tipos = tipos_disponiveis(pg, from.utc.iso8601, to.utc.iso8601)
    ensure
      pg.close
    end

    render json: {
      period: params[:period],
      eventos: eventos,
      kpis: kpis,
      tipos: tipos,
      generatedAt: Time.current.iso8601,
    }
  rescue PG::Error => e
    render json: { error: 'falha ao consultar o PostgreSQL do n8n', detail: e.message }, status: :bad_gateway
  end

  private

  def listar_eventos(pg, from_iso, to_iso)
    where = ['cl.ad_executado = TRUE', 'cl.ad_executado_em IS NOT NULL',
             'cl.ad_executado_em >= $1', 'cl.ad_executado_em <= $2']
    args = [from_iso, to_iso]

    if params[:tipo].present?
      args << params[:tipo].to_s
      where << "COALESCE(cat.nome, 'Categoria ' || cl.glpi_category_id) = $#{args.size}"
    end

    if (res = params[:resultado].to_s).in?(%w[sucesso falha])
      ok = "lower(coalesce(cl.ad_resultado->>'sucesso','')) IN ('true','t','1','sucesso')"
      where << (res == 'sucesso' ? ok : "NOT (#{ok})")
    end

    lcol = local_col(pg) # coluna de "local" disponível neste schema (pode ser nil)

    if params[:search].present?
      args << "%#{params[:search].to_s.strip}%"
      i = args.size
      campos = ["cl.titulo ILIKE $#{i}", "cl.solicitante_nome ILIKE $#{i}",
                "(cl.ad_resultado->>'login') ILIKE $#{i}", "cl.glpi_ticket_id::text ILIKE $#{i}"]
      campos << "cl.#{lcol} ILIKE $#{i}" if lcol
      where << "(#{campos.join(' OR ')})"
    end

    local_sel = lcol ? "cl.#{lcol}" : 'NULL'
    sql = <<~SQL
      SELECT cl.glpi_ticket_id, cl.titulo, cl.solicitante_nome, #{local_sel} AS local_setor,
             cl.glpi_category_id, cl.ad_executado_em, cl.created_at,
             COALESCE(cat.nome, 'Categoria ' || cl.glpi_category_id) AS categoria,
             cl.ad_resultado::text AS resultado_json
        FROM {s}.chamados_log cl
        LEFT JOIN {s}.glpi_categorias cat ON cat.glpi_category_id = cl.glpi_category_id
       WHERE #{where.join(' AND ')}
       ORDER BY cl.ad_executado_em DESC
       LIMIT #{LIMIT}
    SQL

    pg.query(sql, args).map { |r| montar_evento(r) }
  end

  # Primeira coluna de "local/lotação" que existir no chamados_log desta empresa.
  # Schemas variam entre instâncias do GLPI/n8n — daí a detecção dinâmica.
  LOCAL_COLS = %w[coordenadoria setor departamento lotacao secretaria unidade].freeze
  def local_col(pg)
    return @local_col if defined?(@local_col)

    existentes = pg.query(
      "SELECT column_name FROM information_schema.columns " \
      "WHERE table_schema = '{s}' AND table_name = 'chamados_log'"
    ).map { |r| r['column_name'] }
    @local_col = LOCAL_COLS.find { |c| existentes.include?(c) }
  end

  def montar_evento(r)
    res = parse_resultado(r['resultado_json'])
    {
      id: r['glpi_ticket_id'].to_i,
      ticketId: r['glpi_ticket_id'].to_i,
      at: iso(r['ad_executado_em']),
      criadoEm: iso(r['created_at']),
      esperaSeg: espera_seg(r['created_at'], r['ad_executado_em']),
      categoria: r['categoria'],
      categoriaId: r['glpi_category_id'].to_i,
      titulo: r['titulo'],
      solicitante: r['solicitante_nome'],
      setor: r['local_setor'].presence,
      sucesso: sucesso?(res),
      acao: res['acao_real'].presence || r['categoria'],
      login: res['login'],
      erro: res['erro'].presence || res['mensagem'].presence,
      detalhes: detalhes_limpos(res, r['categoria']),
    }
  end

  # Pares chave→valor seguros para exibir no card (sem segredos, sem ruído).
  def detalhes_limpos(res, _categoria)
    mapa = {
      'login' => 'Login', 'dominio' => 'Domínio', 'pasta' => 'Pasta',
      'setor' => 'Novo setor', 'nome_completo' => 'Nome', 'email' => 'E-mail',
      'mensagem' => 'Mensagem', 'erro' => 'Erro'
    }
    res.reject { |k, _| SECRET_RESULT_KEYS.include?(k.to_s.downcase) }
       .filter_map { |k, v| { label: mapa[k.to_s], valor: v.to_s } if mapa[k.to_s] && v.to_s.present? }
  end

  def calcular_kpis(pg, from_iso, to_iso)
    sql = <<~SQL
      SELECT COUNT(*)::int AS total,
             COUNT(*) FILTER (WHERE ad_executado_em::date = CURRENT_DATE)::int AS hoje,
             COUNT(*) FILTER (
               WHERE lower(coalesce(ad_resultado->>'sucesso','')) IN ('true','t','1','sucesso')
             )::int AS sucessos,
             MAX(ad_executado_em) AS ultima
        FROM {s}.chamados_log
       WHERE ad_executado = TRUE AND ad_executado_em IS NOT NULL
         AND ad_executado_em >= $1 AND ad_executado_em <= $2
    SQL
    r = pg.query(sql, [from_iso, to_iso]).first || {}
    total = r['total'].to_i
    sucessos = r['sucessos'].to_i
    {
      total: total,
      hoje: r['hoje'].to_i,
      sucessos: sucessos,
      falhas: total - sucessos,
      taxaSucesso: total.positive? ? (sucessos * 100.0 / total).round : nil,
      ultima: iso(r['ultima']),
    }
  end

  def tipos_disponiveis(pg, from_iso, to_iso)
    sql = <<~SQL
      SELECT DISTINCT COALESCE(cat.nome, 'Categoria ' || cl.glpi_category_id) AS nome
        FROM {s}.chamados_log cl
        LEFT JOIN {s}.glpi_categorias cat ON cat.glpi_category_id = cl.glpi_category_id
       WHERE cl.ad_executado = TRUE AND cl.ad_executado_em >= $1 AND cl.ad_executado_em <= $2
       ORDER BY nome
    SQL
    pg.query(sql, [from_iso, to_iso]).map { |x| x['nome'] }
  end

  def parse_resultado(json)
    v = JSON.parse(json.to_s)
    v.is_a?(Hash) ? v : {}
  rescue JSON::ParserError, TypeError
    {}
  end

  def sucesso?(res)
    %w[true t 1 sucesso].include?(res['sucesso'].to_s.strip.downcase)
  end

  def espera_seg(created, executado)
    return nil if created.blank? || executado.blank?

    (Time.zone.parse(executado.to_s) - Time.zone.parse(created.to_s)).to_i
  rescue ArgumentError, TypeError
    nil
  end

  def iso(v)
    return nil if v.blank?

    (v.is_a?(Time) ? v : Time.zone.parse(v.to_s)).iso8601
  rescue ArgumentError, TypeError
    v.to_s.presence
  end
end
