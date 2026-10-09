class BookingMailer < ApplicationMailer
  # to the customer, once the Paddle webhook confirms payment
  def confirmed
    @booking = params[:booking]

    mail to: @booking.email, subject: t("booking_mailer.confirmed.subject")
  end

  def changed
    @change = params[:change]
    @booking = @change.booking
    I18n.with_locale(@booking.legal_snapshot["locale"] || I18n.default_locale) do
      helper = ApplicationController.new.helpers
      @copy = %w[change_subject canceled_title canceled_body].index_with { |key| helper.content_block("refunds.notifications.#{key}").to_s }
      mail to: @booking.email, subject: @copy.fetch("change_subject")
    end
  end

  # to owner, so a paid session doesn't depend on her watching the calendar
  def new_booking
    @booking = params[:booking]

    # replies go to the customer, so answering the notification reaches them directly
    mail to: ENV.fetch("OWNER_EMAIL"),
         reply_to: @booking.email,
         subject: t("booking_mailer.new_booking.subject", name: @booking.name)
  end

  # to the customer, when the transaction failed or was canceled and we released the slot
  def payment_failed
    @booking = params[:booking]

    mail to: @booking.email, subject: t("booking_mailer.payment_failed.subject")
  end
end
