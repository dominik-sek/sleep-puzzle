# Decides what becomes of the booking behind a Paddle transaction that failed or was
# canceled. The release itself lives in ReleaseFailedBookingJob, so a decline can be
# re-checked after a grace period rather than acted on the moment it is reported.
class BookingPaymentFailureService < PaddleTransactionService
  # How long each kind of failure is left alone before the slot is released.
  #
  # payment_failed is not the end of the transaction: the buyer stays in the checkout,
  # puts in another card, and that very transaction then reports transaction.completed.
  # Releasing on the first decline emails a failure, deletes the calendar hold out from
  # under a payment still in flight, and flashes "Płatność nie powiodła się" on the
  # success page. Canceled has no such retry, so it goes straight through.
  #
  # Keyed by status rather than passed in by the caller on purpose - the delay is a
  # property of the event, and a caller that forgets it would silently reinstate the
  # bug. Comfortably inside ReleaseAbandonedBookingsJob::ABANDON_AFTER, so that sweep
  # stays the last resort.
  GRACE = { "payment_failed" => 15.minutes }.freeze

  def initialize(event:, status:)
    super(event: event)
    @status = status.to_s
  end

  def call
    return if booking.nil?
    # already paid for, or already released - nothing left to decide
    return unless booking.pending?

    wait = GRACE[@status]
    job = wait ? ReleaseFailedBookingJob.set(wait: wait) : ReleaseFailedBookingJob
    job.perform_later(booking.id, @status)

    booking
  end

  private

  def model = Booking
  def custom_data_key = :booking_id
  alias_method :booking, :record
end
