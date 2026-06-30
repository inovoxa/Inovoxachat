# Inventário de TI: leitura DIRETA do MySQL do OCS Inventory (schema ocsweb) da empresa.
# Conexão via Glpi::MysqlClient(prefix: 'OCS_DB'). Somente leitura, paginado.
class Api::V1::Accounts::Glpi::InventarioController < Api::V1::Accounts::Glpi::BaseController
  PER_PAGE_OPTS = [10, 25, 50].freeze

  # GET /api/v1/accounts/:account_id/glpi/inventario?page=1&per_page=10&search=&os=&period=
  def index
    page = [params[:page].to_i, 1].max
    per_page = PER_PAGE_OPTS.include?(params[:per_page].to_i) ? params[:per_page].to_i : 10
    offset = (page - 1) * per_page

    my = Glpi::MysqlClient.new(glpi_config, prefix: 'OCS_DB')
    begin
      where = montar_filtros(my)
      total = my.query("SELECT COUNT(*) AS n FROM hardware h WHERE #{where}").first['n'].to_i
      rows = my.query(<<~SQL)
        SELECT h.ID, h.NAME, h.USERID, h.OSNAME, h.IPADDR, h.LASTDATE, h.WORKGROUP,
               b.SMANUFACTURER, b.SMODEL, b.SSN
          FROM hardware h
          LEFT JOIN bios b ON b.HARDWARE_ID = h.ID
         WHERE #{where}
         ORDER BY h.LASTDATE DESC
         LIMIT #{per_page} OFFSET #{offset}
      SQL
    ensure
      my.close
    end

    render json: {
      itens: rows.map { |r| shape_lista(r) },
      page: page,
      perPage: per_page,
      total: total,
    }
  rescue Mysql2::Error => e
    render json: { error: 'falha ao consultar o MySQL do OCS', detail: e.message }, status: :bad_gateway
  end

  # GET /api/v1/accounts/:account_id/glpi/inventario/:id  (detalhe completo da máquina)
  def show
    id = params[:id].to_i
    my = Glpi::MysqlClient.new(glpi_config, prefix: 'OCS_DB')
    begin
      hw = my.query("SELECT * FROM hardware WHERE ID = #{id}").first
      return render(json: { error: 'máquina não encontrada' }, status: :not_found) unless hw

      bios = safe({}) { my.query("SELECT * FROM bios WHERE HARDWARE_ID = #{id}").first || {} }
      data = {
        hardware: shape_hardware(hw),
        bios: shape_bios(bios),
        redes: safe { my.query("SELECT DESCRIPTION, MACADDR, IPADDRESS, IPMASK, STATUS FROM networks WHERE HARDWARE_ID = #{id}") },
        discos: safe { my.query("SELECT LETTER, TYPE, FILESYSTEM, TOTAL, FREE, VOLUMN FROM drives WHERE HARDWARE_ID = #{id}") },
        memorias: safe { my.query("SELECT CAPTION, DESCRIPTION, CAPACITY, SPEED, TYPE FROM memories WHERE HARDWARE_ID = #{id}") },
        softwares: softwares(my, id),
      }
    ensure
      my.close
    end
    render json: data
  rescue Mysql2::Error => e
    render json: { error: 'falha ao ler a máquina no OCS', detail: e.message }, status: :bad_gateway
  end

  private

  def safe(default = [])
    yield
  rescue StandardError
    default
  end

  def montar_filtros(my)
    conds = ['1=1']
    if params[:search].present?
      q = my.escape(params[:search].to_s.strip[0, 80])
      conds << "(h.NAME LIKE '%#{q}%' OR h.USERID LIKE '%#{q}%' OR h.IPADDR LIKE '%#{q}%' " \
               "OR h.OSNAME LIKE '%#{q}%' OR EXISTS (SELECT 1 FROM bios bb WHERE bb.HARDWARE_ID = h.ID AND bb.SSN LIKE '%#{q}%'))"
    end
    if params[:os].present?
      os = my.escape(params[:os].to_s.strip[0, 60])
      conds << "h.OSNAME LIKE '%#{os}%'"
    end
    # Filtro "último contato" só quando o período é explicitamente pedido.
    if params[:period].present? || params[:from].present?
      from, = date_range
      conds << "h.LASTDATE >= '#{my.escape(from.strftime('%Y-%m-%d %H:%M:%S'))}'"
    end
    conds.join(' AND ')
  end

  # Softwares instalados (schema normalizado do OCS 2.x). Resiliente a variações.
  def softwares(my, id)
    safe do
      my.query(<<~SQL)
        SELECT sn.NAME AS nome, sv.VERSION AS versao, sp.PUBLISHER AS fabricante
          FROM software_installed si
          JOIN software_name sn ON sn.ID = si.NAME_ID
          LEFT JOIN software_version sv ON sv.ID = si.VERSION_ID
          LEFT JOIN software_publisher sp ON sp.ID = si.PUBLISHER_ID
         WHERE si.HARDWARE_ID = #{id}
         ORDER BY sn.NAME
         LIMIT 500
      SQL
    end
  end

  def shape_lista(r)
    {
      id: r['ID'].to_i,
      nome: r['NAME'],
      usuario: r['USERID'],
      so: r['OSNAME'],
      ip: r['IPADDR'],
      ultimoContato: r['LASTDATE'],
      dominio: r['WORKGROUP'],
      fabricante: r['SMANUFACTURER'],
      modelo: r['SMODEL'],
      serial: r['SSN'],
    }
  end

  def shape_hardware(h)
    {
      id: h['ID'].to_i, nome: h['NAME'], usuario: h['USERID'], dominio: h['WORKGROUP'],
      so: h['OSNAME'], soVersao: h['OSVERSION'], arquitetura: h['ARCH'],
      processador: h['PROCESSORT'], processadorMhz: h['PROCESSORS'], nucleos: h['PROCESSORN'],
      memoriaMb: h['MEMORY'], ip: h['IPADDR'], ultimoContato: h['LASTDATE'], ultimoInventario: h['LASTCOME'],
    }
  end

  def shape_bios(b)
    {
      fabricante: b['SMANUFACTURER'], modelo: b['SMODEL'], serial: b['SSN'],
      biosFabricante: b['BMANUFACTURER'], biosVersao: b['BVERSION'], tipo: b['TYPE'],
    }
  end
end
