class Api::V1::Accounts::BookingPagesController < Api::V1::Accounts::BaseController
  before_action :fetch_booking_page, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @booking_pages = Current.account.booking_pages.includes(:availabilities, :inbox, :user)
  end

  def show; end

  def create
    @booking_page = Current.account.booking_pages.create!(permitted_params)
  end

  def update
    @booking_page.update!(permitted_params)
  end

  def destroy
    @booking_page.destroy!
    head :ok
  end

  private

  def fetch_booking_page
    @booking_page = Current.account.booking_pages.find(params[:id])
  end

  def check_authorization
    authorize(@booking_page || BookingPage)
  end

  def permitted_params
    params.require(:booking_page).permit(
      :name, :description, :slug, :duration_minutes, :buffer_before_minutes, :buffer_after_minutes,
      :min_notice_hours, :max_advance_days, :timezone, :active, :inbox_id, :user_id, :default_pipeline_stage_id,
      availabilities_attributes: [:id, :day_of_week, :start_time, :end_time, :_destroy]
    )
  end
end
