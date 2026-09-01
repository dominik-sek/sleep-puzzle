# Decides what becomes of the order behind a Paddle transaction that failed or was
# canceled. The flip itself lives in FailPendingOrderJob, so a decline can be
# re-checked after a grace period rather than acted on the moment it is reported.
#
# The order side of BookingPaymentFailureService, and it exists for the same
# reason that one does: a pending order now holds its products out of the shop,
# the cart and the next checkout, so a payment that never arrives has to release
# them or the buyer can never buy those files again.
class OrderPaymentFailureService < PaddleTransactionService
  # payment_failed is not the end of the transaction: the buyer stays in the
  # checkout, puts in another card, and that very transaction then reports
  # transaction.completed. Acting on the first decline would release the files
  # out from under a payment still in flight and flash a failure on the success
  # page for the second before the completion lands. Canceled has no such retry,
  # so it goes straight through.
  GRACE = { "payment_failed" => 15.minutes }.freeze

  def initialize(event:, status:)
    super(event: event)
    @status = status.to_s
  end

  def call
    return if order.nil?
    # already paid, or already released by the buyer closing the overlay
    return unless order.pending?

    wait = GRACE[@status]
    job = wait ? FailPendingOrderJob.set(wait: wait) : FailPendingOrderJob
    job.perform_later(order.id, @status)

    order
  end

  private

  def model = Order
  def custom_data_key = :order_id
  alias_method :order, :record
end
