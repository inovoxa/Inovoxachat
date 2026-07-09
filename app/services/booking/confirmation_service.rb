# Confirma um BookingRequest: cria/reaproveita o contato, abre uma conversa no
# inbox configurado, registra o CalendarEvent vinculado e dispara os e-mails.
#
# Roda dentro de uma transação; o slot é revalidado antes de gravar para reduzir
# double-booking sob concorrência (ver AvailableSlotsService). Colisões sob corrida
# extrema continuam possíveis — limitação conhecida documentada.
class Booking::ConfirmationService
  class SlotUnavailableError < StandardError; end

  def initialize(booking_page:, params:)
    @page = booking_page
    @params = params
  end

  def perform
    ActiveRecord::Base.transaction do
      revalidate_slot!
      build_request
      create_contact_and_conversation
      create_calendar_event
      link_and_confirm
    end
    send_notifications
    @booking_request
  end

  private

  def start_time
    @start_time ||= Time.zone.parse(@params[:start_time].to_s)
  end

  def end_time
    @end_time ||= start_time + @page.duration_minutes.minutes
  end

  # Confere que o horário pedido ainda consta entre os slots livres do dia.
  def revalidate_slot!
    date_string = start_time.in_time_zone(@page.timezone).to_date.to_s
    available = Booking::AvailableSlotsService.new(@page, date_string).slots
    match = available.any? { |slot| Time.zone.parse(slot[:start_time]).to_i == start_time.to_i }
    raise SlotUnavailableError unless match
  end

  def build_request
    @booking_request = @page.booking_requests.create!(
      guest_name: @params[:guest_name],
      guest_email: @params[:guest_email],
      guest_phone: @params[:guest_phone],
      notes: @params[:notes],
      start_time: start_time,
      end_time: end_time,
      status: :pending
    )
  end

  def create_contact_and_conversation
    contact_inbox = ContactInboxWithContactBuilder.new(
      inbox: @page.inbox,
      contact_attributes: {
        name: @params[:guest_name],
        email: @params[:guest_email],
        phone_number: @params[:guest_phone].presence
      }
    ).perform
    @contact = contact_inbox.contact
    @conversation = ConversationBuilder.new(
      params: ActionController::Parameters.new(status: 'open'),
      contact_inbox: contact_inbox
    ).perform
    create_initial_message
  end

  def create_initial_message
    @conversation.messages.create!(
      account_id: @page.account_id,
      inbox_id: @page.inbox_id,
      message_type: :incoming,
      sender: @contact,
      content: initial_message_content
    )
  end

  def initial_message_content
    when_local = start_time.in_time_zone(@page.timezone).strftime('%d/%m/%Y %H:%M')
    I18n.t('booking.initial_message',
           name: @params[:guest_name],
           page: @page.name,
           datetime: when_local,
           timezone: @page.timezone,
           notes: @params[:notes].presence || '-')
  end

  def create_calendar_event
    @calendar_event = @page.account.calendar_events.create!(
      user: @page.user,
      conversation: @conversation,
      contact: @contact,
      pipeline_stage_id: @page.default_pipeline_stage_id,
      title: "#{@page.name} - #{@params[:guest_name]}",
      description: @params[:notes],
      start_time: start_time,
      end_time: end_time,
      timezone: @page.timezone,
      status: :confirmed,
      source: :internal,
      attendees_attributes: [{ email: @params[:guest_email], name: @params[:guest_name] }]
    )
  end

  def link_and_confirm
    @booking_request.update!(calendar_event: @calendar_event, status: :confirmed)
  end

  def send_notifications
    BookingMailer.with(account: @page.account).confirmation_email(@booking_request).deliver_later
    BookingMailer.with(account: @page.account).agent_notification(@booking_request).deliver_later
  rescue StandardError => e
    Rails.logger.error("[Booking] falha ao enfileirar e-mails do request #{@booking_request&.id}: #{e.message}")
  end
end
