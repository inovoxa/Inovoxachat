class Booking::PagesController < ActionController::Base
  before_action :set_booking_page

  def show; end

  private

  def set_booking_page
    @booking_page = BookingPage.active.find_by(slug: params[:slug])
    render plain: 'Not found', status: :not_found if @booking_page.blank?
  end
end
