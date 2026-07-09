class Public::Api::V1::BookingPagesController < PublicController
  before_action :set_booking_page
  before_action :set_current_account

  def show; end

  def available_slots
    @slots = Booking::AvailableSlotsService.new(@booking_page, params[:date]).slots
    render json: { payload: @slots }
  end

  def bookings
    booking_request = Booking::ConfirmationService.new(
      booking_page: @booking_page,
      params: booking_params
    ).perform

    render json: {
      id: booking_request.id,
      status: booking_request.status,
      ics_url: public_booking_ics_url(@booking_page.slug, booking_request.id)
    }, status: :created
  rescue Booking::ConfirmationService::SlotUnavailableError
    render json: { error: I18n.t('errors.booking.slot_unavailable') }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def ics
    booking_request = @booking_page.booking_requests.confirmed.find(params[:booking_id])
    ics = Booking::IcsGeneratorService.new(booking_request.calendar_event,
                                           organizer_email: @booking_page.user.email).generate
    send_data ics, type: 'text/calendar', filename: 'agendamento.ics', disposition: 'attachment'
  end

  private

  def set_booking_page
    @booking_page = BookingPage.active.find_by!(slug: params[:slug])
  end

  def set_current_account
    Current.account = @booking_page.account
  end

  def booking_params
    params.permit(:guest_name, :guest_email, :guest_phone, :notes, :start_time)
  end

  # Monta a URL de download do .ics a partir do host público.
  def public_booking_ics_url(slug, booking_id)
    base = ENV.fetch('FRONTEND_URL', request.base_url)
    "#{base}/public/api/v1/booking_pages/#{slug}/bookings/#{booking_id}/ics"
  end
end
