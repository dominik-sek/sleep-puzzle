# Releases the booking behind a Paddle transaction that failed or was canceled.
#
# The calendar event is deleted rather than relabelled: leaving it in place would
# keep the slot looking busy to the freebusy query and block a real booking.
class BookingPaymentFailureService < PaddleTransactionService
  def initialize(event:, status:)
    super(event: event)
    @status = status
  end

  def call
    return if booking.nil?

    # a card can fail and then succeed on retry within the same transaction, so a
    # booking that already got its transaction.completed keeps the slot
    return if booking.confirmed?

    booking.fail_payment!(@status)
    BookingCalendarService.call(booking: booking).release
    BookingMailer.with(booking: booking).payment_failed.deliver_later
    Rails.logger.info("Released booking #{booking.id} as #{@status} from Paddle transaction #{transaction_id}")

    booking
  end
end
