# Chamados e Kanban: leitura DIRETA do MySQL do GLPI (+ enriquecimento por chamados_log
# no PostgreSQL) e write-back de status via API v1. Porta tickets.js/ticketQueries.js da Central.
class Api::V1::Accounts::Glpi::TicketsController < Api::V1::Accounts::Glpi::BaseController
  STLABEL = {
    'aberto' => 'Aberto', 'aguardando_aprovacao' => 'Aguardando aprovação',
    'em_execucao' => 'Em execução', 'resolvido' => 'Resolvido', 'violou_sla' => 'Violou SLA'
  }.freeze
  NIVEL = { 1 => 'Muito baixa', 2 => 'Baixa', 3 => 'Média', 4 => 'Alta', 5 => 'Muito alta', 6 => 'Crítica' }.freeze

  SUB_REQUESTER = "(SELECT COALESCE(NULLIF(TRIM(CONCAT_WS(' ', us.firstname, us.realname)), ''), us.name) " \
                  'FROM glpi_tickets_users tu JOIN glpi_users us ON us.id = tu.users_id ' \
                  'WHERE tu.tickets_id = t.id AND tu.type = 1 ORDER BY tu.id LIMIT 1)'
  SUB_ASSIGNEE = "(SELECT COALESCE(NULLIF(TRIM(CONCAT_WS(' ', ua.firstname, ua.realname)), ''), ua.name) " \
                 'FROM glpi_tickets_users tu2 JOIN glpi_users ua ON ua.id = tu2.users_id ' \
                 'WHERE tu2.tickets_id = t.id AND tu2.type = 2 ORDER BY tu2.id LIMIT 1)'
  SUB_TECHGROUP = '(SELECT g.name FROM glpi_groups_tickets gt JOIN glpi_groups g ON g.id = gt.groups_id ' \
                  'WHERE gt.tickets_id = t.id AND gt.type = 2 ORDER BY gt.id LIMIT 1)'

  # GET /api/v1/accounts/:account_id/glpi/tickets?period=180d&search=
  def index
    from, to = date_range
    from_my = from.strftime('%Y-%m-%d %H:%M:%S')
    to_my = to.strftime('%Y-%m-%d %H:%M:%S')
    search = params[:search].to_s.strip[0, 80].to_s
    limit = params[:limit].present? ? [[params[:limit].to_i, 1].max, 500].min : 300

    my = Glpi::MysqlClient.new(glpi_config)
    rows = begin
      list_tickets(my, from_my, to_my, search, limit)
    ensure
      my.close
    end

    enrich = enrich_from_log(rows.map { |r| r['id'] })
    render json: { tickets: rows.map { |r| shape(r, enrich) }, total: rows.size }
  rescue Mysql2::Error => e
    render json: { error: 'falha ao consultar o MySQL do GLPI', detail: e.message }, status: :bad_gateway
  end

  # GET /api/v1/accounts/:account_id/glpi/tickets/:id  (detalhe + timeline + anexos)
  def show
    id = params[:id].to_i
    my = Glpi::MysqlClient.new(glpi_config)
    d = fups = tasks = sols = docs = nil
    begin
      d = ticket_detail(my, id)
      return render(json: { error: 'chamado não encontrado' }, status: :not_found) unless d

      # Partes da timeline são opcionais: se uma falhar, mostra o resto.
      fups = safe { ticket_followups(my, id) }
      tasks = safe { ticket_tasks(my, id) }
      sols = safe { ticket_solution(my, id) }
      docs = safe { ticket_documents(my, id) }
    ensure
      my.close
    end

    log = (enrich_from_log([id])[id] || {})
    breached = Glpi::TicketMap.breached?(glpi_status: d['glpi_status'], ttr: d['ttr'], solvedate: d['solvedate'])
    status = breached ? 'violou_sla' : Glpi::TicketMap.status_to_column(d['glpi_status'])

    render json: {
      ticket: {
        id: d['id'], titulo: d['titulo'], descricao: strip_html(d['content']),
        sol: d['solicitante'].presence || '—', assignee: d['assignee'].presence || '—',
        sector: log[:secretaria].presence || '—', canal: log[:canal].presence || 'Manual',
        cat: d['categoria'].presence || 'Sem categoria', status: status, statusLabel: STLABEL[status],
        prio: Glpi::TicketMap.priority_label(d['priority']),
        urgencia: NIVEL[d['urgency'].to_i] || '—', impacto: NIVEL[d['impact'].to_i] || '—',
        entidade: d['entidade'].presence || '—', local: d['local_'].presence || '—',
        grupoTecnico: d['grupo_tecnico'].presence || '—',
        sla: Glpi::TicketMap.sla_percent(date: d['date'], ttr: d['ttr'], solvedate: d['solvedate']),
        abertoFull: fmt_full(d['date'])
      },
      anexos: docs.map { |x| { nome: x['name'].presence || x['filename'], arquivo: x['filename'], mime: x['mime'] } },
      timeline: build_timeline(d, fups, tasks, sols)
    }
  rescue Mysql2::Error => e
    render json: { error: 'falha ao ler o chamado no GLPI', detail: e.message }, status: :bad_gateway
  end

  # PATCH /api/v1/accounts/:account_id/glpi/tickets/:id/status
  def status
    glpi_status = Glpi::TicketMap.column_to_status(params[:status])
    return render(json: { error: 'coluna não gravável' }, status: :unprocessable_entity) unless glpi_status

    pg = Glpi::PgClient.new(glpi_config)
    begin
      write_status(pg, params[:id], glpi_status)
    ensure
      pg.close
    end
    render json: { ok: true, id: params[:id].to_i, status: params[:status] }
  rescue StandardError => e
    render json: { error: 'não foi possível atualizar o chamado no GLPI', detail: e.message }, status: :bad_gateway
  end

  private

  def safe(default = [])
    yield
  rescue StandardError
    default
  end

  # Write-back de status: tenta a API v2 (OAuth, Cliente OAuth); se falhar, usa a v1 (comprovada).
  def write_status(pg, id, glpi_status)
    Glpi::V2Client.new(glpi_config, pg).update_ticket_status(id, glpi_status)
  rescue StandardError => e
    Rails.logger.warn("[glpi] write-back v2 (OAuth) falhou (#{e.message}); usando v1")
    Glpi::V1Client.new(glpi_config, pg).update_ticket_status(id, glpi_status)
  end

  def list_tickets(my, from_my, to_my, search, limit)
    where = ['t.is_deleted = 0', "t.date >= '#{my.escape(from_my)}'", "t.date <= '#{my.escape(to_my)}'"]
    if search.present?
      q = my.escape(search)
      qid = search.match?(/\A\d+\z/) ? search.to_i : -1
      # Busca por título, #, local ou nome do solicitante.
      where << "(t.name LIKE '%#{q}%' OR t.id = #{qid} OR l.completename LIKE '%#{q}%' " \
               "OR EXISTS (SELECT 1 FROM glpi_tickets_users tus JOIN glpi_users uss ON uss.id = tus.users_id " \
               "WHERE tus.tickets_id = t.id AND tus.type = 1 AND " \
               "(uss.name LIKE '%#{q}%' OR CONCAT_WS(' ', uss.firstname, uss.realname) LIKE '%#{q}%')))"
    end

    my.query(<<~SQL)
      SELECT t.id, t.name AS titulo, t.date AS date, t.status AS glpi_status,
             t.priority AS priority, t.time_to_resolve AS ttr, t.solvedate AS solvedate,
             c.completename AS categoria, e.name AS entidade, l.completename AS local_,
             #{SUB_TECHGROUP} AS grupo_tecnico, #{SUB_REQUESTER} AS solicitante, #{SUB_ASSIGNEE} AS assignee
        FROM glpi_tickets t
        LEFT JOIN glpi_itilcategories c ON c.id = t.itilcategories_id
        LEFT JOIN glpi_entities e ON e.id = t.entities_id
        LEFT JOIN glpi_locations l ON l.id = t.locations_id
       WHERE #{where.join(' AND ')}
       ORDER BY t.date DESC
       LIMIT #{limit}
    SQL
  end

  def ticket_detail(my, id)
    my.query(<<~SQL).first
      SELECT t.id, t.name AS titulo, t.content, t.date, t.status AS glpi_status,
             t.priority, t.urgency, t.impact, t.time_to_resolve AS ttr, t.solvedate, t.closedate,
             c.completename AS categoria, e.name AS entidade, l.completename AS local_,
             #{SUB_TECHGROUP} AS grupo_tecnico, #{SUB_REQUESTER} AS solicitante, #{SUB_ASSIGNEE} AS assignee
        FROM glpi_tickets t
        LEFT JOIN glpi_itilcategories c ON c.id = t.itilcategories_id
        LEFT JOIN glpi_entities e ON e.id = t.entities_id
        LEFT JOIN glpi_locations l ON l.id = t.locations_id
       WHERE t.id = #{id.to_i} AND t.is_deleted = 0
       LIMIT 1
    SQL
  end

  def ticket_followups(my, id)
    my.query(<<~SQL)
      SELECT f.date, f.content,
             COALESCE(NULLIF(TRIM(CONCAT_WS(' ', u.firstname, u.realname)), ''), u.name) AS autor
        FROM glpi_itilfollowups f LEFT JOIN glpi_users u ON u.id = f.users_id
       WHERE f.itemtype = 'Ticket' AND f.items_id = #{id.to_i} ORDER BY f.date
    SQL
  end

  def ticket_tasks(my, id)
    my.query(<<~SQL)
      SELECT tt.date, tt.content,
             COALESCE(NULLIF(TRIM(CONCAT_WS(' ', u.firstname, u.realname)), ''), u.name) AS autor
        FROM glpi_tickettasks tt LEFT JOIN glpi_users u ON u.id = tt.users_id
       WHERE tt.tickets_id = #{id.to_i} ORDER BY tt.date
    SQL
  end

  def ticket_solution(my, id)
    my.query("SELECT s.date, s.content FROM glpi_itilsolutions s " \
             "WHERE s.itemtype = 'Ticket' AND s.items_id = #{id.to_i} ORDER BY s.date")
  end

  def ticket_documents(my, id)
    my.query(<<~SQL)
      SELECT d.name, d.filename, d.mime
        FROM glpi_documents_items di JOIN glpi_documents d ON d.id = di.documents_id
       WHERE di.itemtype = 'Ticket' AND di.items_id = #{id.to_i} ORDER BY d.name
    SQL
  end

  def build_timeline(d, fups, tasks, sols)
    tl = []
    tl << { tipo: 'abertura', when: iso(d['date']), autor: d['solicitante'], texto: 'Chamado aberto' } if d['date']
    fups.each { |f| tl << { tipo: 'followup', when: iso(f['date']), autor: f['autor'], texto: strip_html(f['content']) } }
    tasks.each { |t| tl << { tipo: 'tarefa', when: iso(t['date']), autor: t['autor'], texto: strip_html(t['content']) } }
    sols.each { |s| tl << { tipo: 'solucao', when: iso(s['date']), autor: nil, texto: strip_html(s['content']) } }
    tl << { tipo: 'resolvido', when: iso(d['solvedate']), texto: 'Chamado solucionado' } if d['solvedate']
    tl << { tipo: 'fechado', when: iso(d['closedate']), texto: 'Chamado fechado' } if d['closedate']
    tl.sort_by { |x| x[:when].to_s }
  end

  def enrich_from_log(ids)
    ids = ids.map(&:to_i).reject(&:zero?)
    return {} if ids.empty?

    pg = Glpi::PgClient.new(glpi_config)
    rows = pg.query("SELECT glpi_ticket_id, secretaria, conversa_id FROM {s}.chamados_log WHERE glpi_ticket_id IN (#{ids.join(',')})")
    rows.each_with_object({}) do |r, map|
      map[r['glpi_ticket_id'].to_i] = {
        secretaria: r['secretaria'],
        canal: r['conversa_id'].to_s.present? ? 'WhatsApp' : 'Formulário'
      }
    end
  rescue StandardError
    {} # enriquecimento é opcional: se o PostgreSQL falhar, mostra os chamados sem setor/canal
  ensure
    pg&.close
  end

  def shape(row, enrich)
    log = enrich[row['id'].to_i] || {}
    breached = Glpi::TicketMap.breached?(glpi_status: row['glpi_status'], ttr: row['ttr'], solvedate: row['solvedate'])
    status = breached ? 'violou_sla' : Glpi::TicketMap.status_to_column(row['glpi_status'])
    {
      id: row['id'], sol: row['solicitante'].presence || '—',
      sector: log[:secretaria].presence || '—', cat: row['categoria'].presence || 'Sem categoria',
      canal: log[:canal].presence || 'Manual', status: status, statusLabel: STLABEL[status],
      sla: Glpi::TicketMap.sla_percent(date: row['date'], ttr: row['ttr'], solvedate: row['solvedate']),
      assignee: row['assignee'].presence || '—', prio: Glpi::TicketMap.priority_label(row['priority']),
      entidade: row['entidade'].presence || '—', local: row['local_'].presence || '—',
      grupoTecnico: row['grupo_tecnico'].presence || '—', abertoRel: rel_time(row['date'])
    }
  end

  def strip_html(str)
    str.to_s
       .gsub(%r{<br\s*/?>}i, "\n").gsub(%r{</p>}i, "\n").gsub(/<[^>]+>/, '')
       .gsub('&nbsp;', ' ').gsub('&amp;', '&').gsub('&lt;', '<').gsub('&gt;', '>')
       .gsub('&#39;', "'").gsub('&quot;', '"').gsub(/\n{3,}/, "\n\n").strip
  end

  def iso(value)
    return nil if value.nil?

    (value.is_a?(Time) ? value : Time.parse(value.to_s)).utc.iso8601
  rescue StandardError
    nil
  end

  def fmt_full(date)
    t = date.is_a?(Time) ? date : (Time.parse(date.to_s) rescue nil)
    t ? t.strftime('%d/%m/%Y %H:%M') : '—'
  end

  def rel_time(date)
    return '' if date.nil?

    t = date.is_a?(Time) ? date : (Time.parse(date.to_s) rescue nil)
    return '' unless t

    m = ((Time.now - t) / 60).round
    return 'agora' if m < 1
    return "há #{m} min" if m < 60

    h = (m / 60.0).round
    return "há #{h}h" if h < 24

    "há #{(h / 24.0).round}d"
  end
end
