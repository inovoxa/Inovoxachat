module Glpi
  # Mapeamentos GLPI -> modelo do painel. Porta backend/src/lib/ticketMap.js.
  module TicketMap
    module_function

    # Status GLPI -> coluna do Kanban. (1 novo, 2 atribuído, 3 planejado, 4 pendente, 5 solucionado, 6 fechado)
    def status_to_column(glpi_status)
      case glpi_status.to_i
      when 1 then 'aberto'
      when 4 then 'aguardando_aprovacao'
      when 2, 3 then 'em_execucao'
      when 5, 6 then 'resolvido'
      else 'aberto'
      end
    end

    # Coluna do Kanban -> status GLPI (para gravar). 'violou_sla' é derivada (não grava).
    def column_to_status(col)
      { 'aberto' => 1, 'aguardando_aprovacao' => 4, 'em_execucao' => 2, 'resolvido' => 5 }[col.to_s]
    end

    def priority_label(p)
      p = p.to_i
      return 'Baixa' if p <= 2
      return 'Média' if p == 3
      return 'Alta' if p == 4

      'Crítica'
    end

    # % de SLA restante para a barra. nil se o ticket não tem prazo (time_to_resolve).
    def sla_percent(date:, ttr:, solvedate:)
      return nil if ttr.nil?

      ttr_ms = to_ms(ttr)
      return (to_ms(solvedate) <= ttr_ms ? 100 : 0) if solvedate

      start_ms = date ? to_ms(date) : ttr_ms
      now = now_ms
      total = ttr_ms - start_ms
      return (now <= ttr_ms ? 100 : 0) if total <= 0

      rem = ttr_ms - now
      [[((rem / total) * 100).round, 100].min, 0].max
    end

    # Ticket não resolvido cujo prazo passou = violou SLA.
    def breached?(glpi_status:, ttr:, solvedate:)
      return false if [5, 6].include?(glpi_status.to_i) || ttr.nil?

      now_ms > to_ms(ttr)
    end

    def now_ms
      Time.now.to_f * 1000
    end

    def to_ms(value)
      return value.to_f * 1000 if value.is_a?(Time)

      Time.parse(value.to_s).to_f * 1000
    rescue StandardError
      0
    end
  end
end
