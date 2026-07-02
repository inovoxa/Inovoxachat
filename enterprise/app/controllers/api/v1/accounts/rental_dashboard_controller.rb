# Painel de Controle do módulo Empresas: agrega contratos a vencer, inadimplência,
# equipamentos, funil de vendas e a timeline de vencimentos. Read-only, escopado por conta.
class Api::V1::Accounts::RentalDashboardController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_companies_enabled!

  def show
    acc = Current.account
    render json: {
      cards: cards(acc),
      timeline: timeline(acc),
      empresas_atencao: empresas_atencao(acc)
    }
  end

  private

  def cards(acc)
    {
      contratos_vencendo_7: acc.contracts.vencendo_em(7).count,
      contratos_vencendo_30: acc.contracts.vencendo_em(30).count,
      contratos_vencidos: acc.contracts.ativo.vencidos_por_data.count,
      inadimplencia_count: acc.invoices.inadimplencia.count,
      inadimplencia_total: acc.invoices.inadimplencia.sum(:amount).to_f,
      faturas_semana: acc.invoices.vencendo_em(7).count,
      faturas_semana_total: acc.invoices.vencendo_em(7).sum(:amount).to_f,
      equipamentos_alugados: acc.equipments.alugado.count,
      equipamentos_manutencao: acc.equipments.manutencao.count,
      funil_abertas: acc.opportunities.abertas.count,
      funil_valor: acc.opportunities.abertas.sum(:expected_value).to_f
    }
  end

  # Próximos 30 dias: contratos e faturas que vencem, ordenados por data.
  def timeline(acc)
    itens = []
    acc.contracts.ativo.where(end_date: Date.current..(Date.current + 30)).includes(:company).each do |c|
      itens << { tipo: 'contrato', id: c.id, data: c.end_date, empresa: c.company&.name, valor: c.value.to_f }
    end
    acc.invoices.vencendo_em(30).includes(:company).each do |f|
      itens << { tipo: 'fatura', id: f.id, data: f.due_date, empresa: f.company&.name, valor: f.amount.to_f }
    end
    itens.sort_by { |i| i[:data] }.first(30)
  end

  # Empresas com faturas vencidas, ranqueadas por valor em aberto.
  def empresas_atencao(acc)
    acc.invoices.inadimplencia.includes(:company).group_by(&:company_id).map do |company_id, faturas|
      {
        company_id: company_id,
        empresa: faturas.first.company&.name,
        total: faturas.sum { |f| f.amount.to_f },
        qtd: faturas.size
      }
    end.sort_by { |x| -x[:total] }.first(10)
  end

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end
end
