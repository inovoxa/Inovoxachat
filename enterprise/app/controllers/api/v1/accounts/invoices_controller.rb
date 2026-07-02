class Api::V1::Accounts::InvoicesController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_companies_enabled!
  before_action :fetch_invoice, only: [:show, :update, :destroy, :pagar]

  # GET /invoices?filter=pendentes|inadimplencia|pagas  |  ?company_id=
  def index
    @invoices = filtered_invoices.includes(:company, :contract).order(due_date: :asc)
  end

  def show; end

  def create
    @invoice = Current.account.invoices.create!(invoice_params)
    render :show
  end

  def update
    @invoice.update!(invoice_params)
    render :show
  end

  # POST pagar — marca a fatura como paga.
  def pagar
    @invoice.pagar!
    render :show
  end

  def destroy
    @invoice.destroy!
    head :ok
  end

  private

  def filtered_invoices
    scope = Current.account.invoices.for_company(params[:company_id])
    case params[:filter]
    when 'pendentes' then scope.pendentes
    when 'inadimplencia' then scope.inadimplencia
    when 'pagas' then scope.pagas
    else scope.by_status(params[:status])
    end
  end

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def fetch_invoice
    @invoice = Current.account.invoices.find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(:company_id, :contract_id, :due_date, :amount, :status, :paid_at)
  end
end
