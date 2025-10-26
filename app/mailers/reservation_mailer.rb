class ReservationMailer < ApplicationMailer
  helper ApplicationHelper

  def confirmation_email
    @reservation = params[:reservation]
    @guest_token = params[:guest_token]

    mail(
      to: @reservation.contact_email.presence || @reservation.user&.email,
      subject: I18n.t('reservation_mailer.confirmation_subject', restaurant: 'Restaurant Reservation', date: @reservation.formatted_date, time: @reservation.formatted_time)
    )
  end

  def cancellation_email
    @reservation = params[:reservation]

    mail(
      to: @reservation.contact_email.presence || @reservation.user&.email,
      subject: I18n.t('reservation_mailer.cancellation_subject', restaurant: 'Restaurant Reservation', date: @reservation.formatted_date, time: @reservation.formatted_time)
    )
  end
end
