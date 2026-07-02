# Copilot tool: consulta o inventário de TI (OCS Inventory) da empresa (read-only).
# Conexão direta ao MySQL do OCS via GlpiAccountConfig (multi-empresa).
class Captain::Tools::Copilot::GlpiInventoryService < Captain::Tools::BaseTool
  def self.name
    'glpi_inventory_lookup'
  end

  description 'Consulta o inventário de TI (OCS Inventory) da empresa: máquinas/computadores por ' \
              'sistema operacional, usuário, nome ou IP. Use para perguntas sobre equipamentos, ' \
              'quantidade de máquinas, qual sistema operacional, etc. Somente leitura.'
  param :os, type: :string, desc: 'Filtrar por sistema operacional (ex.: Windows 10). Opcional.'
  param :termo, type: :string, desc: 'Buscar por nome da máquina, usuário ou IP. Opcional.'

  def execute(os: nil, termo: nil)
    cfg = glpi_config
    return 'Integração de inventário (OCS) não configurada para esta conta.' unless cfg&.usable?

    my = Glpi::MysqlClient.new(cfg, prefix: 'OCS_DB')
    begin
      cond = montar_cond(my, os, termo)
      total = my.query("SELECT COUNT(*) AS n FROM hardware h WHERE #{cond}").first['n'].to_i
      amostra = my.query(
        "SELECT h.NAME, h.USERID, h.OSNAME, h.IPADDR, h.LASTDATE FROM hardware h " \
        "WHERE #{cond} ORDER BY h.LASTDATE DESC LIMIT 15"
      )
      formatar(total, amostra, os, termo)
    ensure
      my.close
    end
  rescue StandardError => e
    "Erro ao consultar o inventário: #{e.message}"
  end

  def active?
    glpi_config&.usable? || false
  end

  private

  def glpi_config
    GlpiAccountConfig.find_by(account_id: @assistant.account_id)
  end

  def montar_cond(my, os, termo)
    conds = ['1=1']
    conds << "h.OSNAME LIKE '%#{my.escape(os)}%'" if os.present?
    if termo.present?
      t = my.escape(termo)
      conds << "(h.NAME LIKE '%#{t}%' OR h.USERID LIKE '%#{t}%' OR h.IPADDR LIKE '%#{t}%')"
    end
    conds.join(' AND ')
  end

  def formatar(total, amostra, os, termo)
    filtro = [os.present? ? "SO ~ #{os}" : nil, termo.present? ? "busca ~ #{termo}" : nil].compact.join(', ')
    header = "Total de máquinas no inventário#{filtro.present? ? " (#{filtro})" : ''}: #{total}."
    return header if amostra.empty?

    linhas = amostra.map do |m|
      "- #{m['NAME']} | usuário: #{m['USERID']} | SO: #{m['OSNAME']} | IP: #{m['IPADDR']} | visto: #{m['LASTDATE']}"
    end
    "#{header}\nAmostra (até 15):\n#{linhas.join("\n")}"
  end
end
