# Confirms the booking a completed Paddle transaction paid for.
class BookingConfirmationService < PaddleTransactionService
  def call
    # Paddle redelivers on any non-2xx, and Pay retries the job, so the same
    # transaction can arrive more than once
    return if Booking.exists?(paddle_transaction_id: transaction_id)

    # money has changed hands and there is nothing to credit it to — a discarded
    # checkout deletes its booking, so a completion arriving after that needs a human
    if booking.nil?
      Rails.logger.error("[paddle] transaction #{transaction_id} completed but no booking could be matched")
      return
    end

    if booking.confirm_payment!(transaction_id)
      BookingCalendarService.call(booking: booking).sync_status
      # deliver_later so a mail outage can retry on its own without failing the
      # webhook job and re-running everything above it
      BookingMailer.with(booking: booking).confirmed.deliver_later
      BookingMailer.with(booking: booking).new_booking.deliver_later
      Rails.logger.info("Confirmed booking #{booking.id} from Paddle transaction #{transaction_id}")
    end

    booking
  end

  private

  def model = Booking
  def custom_data_key = :booking_id
  # reads as what it is everywhere above, rather than a generic "record"
  alias_method :booking, :record
end
