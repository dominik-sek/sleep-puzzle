# Closing the Paddle overlay without paying fires no webhook at all — Paddle only
# reports transactions the buyer actually attempted. Without this sweep those
# bookings stay pending forever and their calendar event keeps holding the slot.
class ReleaseAbandonedBookingsJob < ApplicationJob
  queue_as :default

  # Long enough that a slow-but-real payment is never cut off. Paddle's delayed
  # methods (bank transfer) can legitimately stay unpaid for days, so raise this
  # well past their settlement window before enabling any of them.
  ABANDON_AFTER = 1.hour

  def perform
    Booking.pending.where(created_at: ..ABANDON_AFTER.ago).find_each do |booking|
      booking.fail_payment!(:canceled)
      BookingCalendarService.call(booking: booking).release
      Rails.logger.info("Released abandoned booking #{booking.id}")
    end
  end
end
