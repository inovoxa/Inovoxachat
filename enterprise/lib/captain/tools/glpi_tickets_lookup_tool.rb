# Captain tool (read-only): consulta chamados (tickets) do GLPI da empresa.
# Usa a conexão direta ao MySQL do GLPI configurada em GlpiAccountConfig (multi-tenant).
class Captain::Tools::GlpiTicketsLookupTool < Captain::Tools::BasePublicTool
  description 'Consulta chamados (tickets) do GLPI da empresa. Use para o status de um chamado ' \
              'específico (por número) ou para contar/listar chamados por status. Somente leitura.'
  param :ticket_id, type: 'string', desc: 'Número do chamado a consultar. Opcional.', required: false
  param :status, type: 'string',
                 desc: 'Filtrar por status: novo, em_atendimento, pendente, resolvido, fechado. Opcional.',
                 required: false

  GLPI_STATUS = { 1 => 'Novo', 2 => 'Em atendimento', 3 => 'Em atendimento',
                  4 => 'Pendente', 5 => 'Resolvido', 6 => 'Fechado' }.freeze
  STATUS_MAP = { 'novo' => 1, 'em_atendimento' => 2, 'pendente' => 4,
                 'resolvido' => 5, 'fechado' => 6 }.freeze

  def perform(_tool_context, ticket_id: nil, status: nil)
    log_tool_usage('searching', { ticket_id: ticket_id, status: status })
    cfg = glpi_config
    return 'Integração GLPI não configurada para esta conta.' unless cfg&.usable?

    my = Glpi::MysqlClient.new(cfg, prefix: 'GLPI_DB')
    begin
      ticket_id.present? ? consultar_um(my, ticket_id.to_i) : listar(my, status)
    ensure
      my.close
    end
  rescue StandardError => e
    "Erro ao consultar chamados: #{e.message}"
  end

  private

  def glpi_config
    GlpiAccountConfig.find_by(account_id: @assistant.account_id)
  end

  def consultar_um(my, id)
    r = my.query("SELECT id, name, status, date, solvedate FROM glpi_tickets WHERE is_deleted = 0 AND id = #{id}").first
    return "Chamado ##{id} não encontrado." unless r

    txt = "Chamado ##{r['id']}: #{r['name']}\nStatus: #{GLPI_STATUS[r['status'].to_i] || r['status']}\n" \
          "Aberto em: #{r['date']}"
    txt += "\nResolvido em: #{r['solvedate']}" if r['solvedate'].present?
    txt
  end

  def listar(my, status)
    conds = ['is_deleted = 0']
    s = STATUS_MAP[status.to_s.downcase]
    conds << "status = #{s}" if s
    cond = conds.join(' AND ')
    total = my.query("SELECT COUNT(*) AS n FROM glpi_tickets WHERE #{cond}").first['n'].to_i
    amostra = my.query("SELECT id, name, status, date FROM glpi_tickets WHERE #{cond} ORDER BY date DESC LIMIT 15")
    header = "Total de chamados#{status.present? ? " (status: #{status})" : ''}: #{total}."
    return header if amostra.empty?

    linhas = amostra.map { |t| "- ##{t['id']} | #{t['name']} | #{GLPI_STATUS[t['status'].to_i]} | #{t['date']}" }
    "#{header}\nMais recentes:\n#{linhas.join("\n")}"
  end
end
