# Flips a booking that never got paid to a failed status and frees the slot.
#
# Kept out of the webhook path on purpose: `transaction.payment_failed` does not
# close a Paddle transaction. The buyer stays in the checkout, enters another card,
# and that *same* transaction then reports `transaction.completed`. Releasing on the
# first decline emails the buyer a failure, deletes the calendar hold out from under
# a payment still in flight, and flashes "Płatność nie powiodła się" on the success
# page for the second or two before the completion lands. So the webhook schedules
# this instead, and it re-reads the booking before touching anything.
class ReleaseFailedBookingJob < ApplicationJob
  queue_as :default

  def perform(booking_id, status)
    booking = Booking.find_by(id: booking_id)
    # gone, confirmed in the meantime (the retry went through), or already released
    # by the buyer closing the overlay or an earlier delivery of the same webhook
    return unless booking&.pending?

    booking.fail_payment!(status)
    BookingCalendarService.call(booking: booking).release
    BookingMailer.with(booking: booking).payment_failed.deliver_later
    Rails.logger.info("Released booking #{booking.id} as #{status}")
  end
end
