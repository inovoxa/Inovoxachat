# Copilot tool: consulta chamados (tickets) do GLPI/Service Desk da empresa (read-only).
# Conexão direta ao MySQL do GLPI via GlpiAccountConfig (multi-empresa).
class Captain::Tools::Copilot::GlpiTicketsService < Captain::Tools::BaseTool
  def self.name
    'glpi_tickets_lookup'
  end

  description 'Consulta chamados (tickets) do GLPI / Service Desk da empresa: status de um chamado ' \
              'por número, ou contagem e lista por status. Use para perguntas sobre chamados, ' \
              'tickets, quantos estão pendentes/abertos/em execução, etc. Somente leitura.'
  param :ticket_id, type: :string, desc: 'Número do chamado a consultar. Opcional.'
  param :status, type: :string,
                 desc: 'Filtrar por status: novo, em_atendimento, pendente, resolvido, fechado. Vazio = resumo geral.'

  GLPI_STATUS = { 1 => 'Novo', 2 => 'Em atendimento', 3 => 'Em atendimento',
                  4 => 'Pendente', 5 => 'Resolvido', 6 => 'Fechado' }.freeze
  STATUS_MAP = { 'novo' => 1, 'em_atendimento' => 2, 'pendente' => 4,
                 'resolvido' => 5, 'fechado' => 6 }.freeze

  def execute(ticket_id: nil, status: nil)
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

  def active?
    glpi_config&.usable? || false
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
    s = STATUS_MAP[status.to_s.downcase]
    return resumo(my) if s.nil?

    cond = "is_deleted = 0 AND status = #{s}"
    total = my.query("SELECT COUNT(*) AS n FROM glpi_tickets WHERE #{cond}").first['n'].to_i
    amostra = my.query("SELECT id, name, status, date FROM glpi_tickets WHERE #{cond} ORDER BY date DESC LIMIT 15")
    header = "Total de chamados com status \"#{status}\": #{total}."
    return header if amostra.empty?

    linhas = amostra.map { |t| "- ##{t['id']} | #{t['name']} | #{GLPI_STATUS[t['status'].to_i]} | #{t['date']}" }
    "#{header}\nMais recentes:\n#{linhas.join("\n")}"
  end

  # Sem filtro: total geral + quebra por status.
  def resumo(my)
    rows = my.query('SELECT status, COUNT(*) AS n FROM glpi_tickets WHERE is_deleted = 0 GROUP BY status')
    por = Hash.new(0)
    rows.each { |r| por[GLPI_STATUS[r['status'].to_i] || "Status #{r['status']}"] += r['n'].to_i }
    total = por.values.sum
    "Total de chamados: #{total}. Por status: #{por.map { |k, v| "#{k}: #{v}" }.join(', ')}."
  end
end
