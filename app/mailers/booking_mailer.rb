class BookingMailer < ApplicationMailer
  # Templates ERB autocontidos; dispensa o layout liquid padrão dos mailers.
  layout false

  # E-mail de confirmação ao convidado, com o convite .ics anexado.
  def confirmation_email(booking_request)
    @booking_request = booking_request
    @page = booking_request.booking_page
    @event = booking_request.calendar_event
    return unless smtp_config_set_or_development?

    attach_ics
    mail(to: booking_request.guest_email,
         subject: I18n.t('booking.mailer.confirmation.subject', page: @page.name))
  end

  # Notificação interna ao agente dono da agenda.
  def agent_notification(booking_request)
    @booking_request = booking_request
    @page = booking_request.booking_page
    @event = booking_request.calendar_event
    return unless smtp_config_set_or_development?
    return if @page.user.email.blank?

    mail(to: @page.user.email,
         subject: I18n.t('booking.mailer.agent.subject', guest: booking_request.guest_name))
  end

  private

  def attach_ics
    return if @event.blank?

    ics = Booking::IcsGeneratorService.new(@event, organizer_email: @page.user.email).generate
    attachments['agendamento.ics'] = { mime_type: 'text/calendar', content: ics }
  end
end
