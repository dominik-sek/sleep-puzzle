# Flips an order that never got paid to a failed status, which is what puts its
# products back on sale for that buyer.
#
# Kept out of the webhook path on purpose: `transaction.payment_failed` does not
# close a Paddle transaction - the buyer stays in the checkout and tries another
# card - so the webhook schedules this and it re-reads the order before touching
# anything. See OrderPaymentFailureService::GRACE.
class FailPendingOrderJob < ApplicationJob
  queue_as :default

  def perform(order_id, status)
    order = Order.find_by(id: order_id)
    # gone, paid in the meantime (the retry went through), or already released by
    # the buyer closing the overlay or an earlier delivery of the same webhook
    return unless order&.pending?

    order.fail_payment!(status)
    Rails.logger.info("Released order #{order.id} as #{status}")
  end
end
