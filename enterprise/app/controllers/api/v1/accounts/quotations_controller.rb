class Api::V1::Accounts::QuotationsController < Api::V1::Accounts::EnterpriseAccountsController
  before_action :ensure_companies_enabled!
  before_action :fetch_quotation, only: [:show, :update, :destroy, :confirm, :send_quote, :cancel]

  # GET /quotations?status=cotacao&company_id=
  def index
    @quotations = Current.account.quotations
                         .by_status(params[:status])
                         .for_company(params[:company_id])
                         .includes(:company, :contact, :agent)
                         .ordered
  end

  def show; end

  def create
    @quotation = Current.account.quotations.create!(quotation_params)
    render :show
  end

  def update
    @quotation.update!(quotation_params)
    render :show
  end

  def destroy
    @quotation.destroy!
    head :ok
  end

  # POST /quotations/:id/confirm — vira pedido de venda e gera contrato
  def confirm
    @quotation.confirmar!
    render :show
  end

  # POST /quotations/:id/send_quote — marca como enviada
  def send_quote
    @quotation.update!(status: :enviada)
    render :show
  end

  # POST /quotations/:id/cancel
  def cancel
    @quotation.update!(status: :cancelada)
    render :show
  end

  private

  def ensure_companies_enabled!
    return if Current.account.feature_enabled?('companies')

    render json: { error: 'Companies are not enabled for this account' }, status: :forbidden
  end

  def fetch_quotation
    @quotation = Current.account.quotations.find(params[:id])
  end

  def quotation_params
    params.require(:quotation).permit(
      :company_id, :contact_id, :agent_id, :opportunity_id, :status,
      :expiration_date, :recurring_plan, :recurring_until, :payment_terms,
      :delivery_date, :notes,
      quotation_lines_attributes: [
        :id, :equipment_id, :is_section, :name, :qty, :unit_price,
        :tax_percent, :discount_percent, :position, :_destroy
      ]
    )
  end
end
