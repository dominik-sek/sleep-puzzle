# Confirms the booking a completed Paddle transaction paid for.
class BookingConfirmationService < PaddleTransactionService
  def call
    # Paddle redelivers on any non-2xx, and Pay retries the job, so the same
    # transaction can arrive more than once
    return if Booking.exists?(paddle_transaction_id: transaction_id)
    return if booking.nil?

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
end
