# Booking side effects for the Paddle transaction webhooks.
#
# ActiveSupport::Notifications runs these before Pay's own charge sync, so don't
# expect a Pay::Charge to exist here yet. If that later sync raises (Paddle API
# down, transaction not yet queryable) the Pay::Webhook row survives and the job
# retries the whole chain - which is why these services have to be idempotent
# rather than assume they run once.
#
# Pay's webhook controller silently drops events nothing is subscribed to, so an
# event type has to be listed here before it is even stored.
# Both run for every completed transaction and each ignores the ones that do not
# name it: a booking checkout puts booking_id in custom_data, an order puts
# order_id, so the other service finds nothing and says so in the log.
Pay::Webhooks.delegator.subscribe "paddle_billing.transaction.completed" do |event|
  BookingConfirmationService.call(event: event)
  OrderConfirmationService.call(event: event)
end

# Neither of these releases the slot or the files on the spot - the two services'
# GRACE decides how long each failure waits first, and the jobs they schedule
# re-check that nothing has paid by then.
#
# Both sides are subscribed for the same reason as above: a failed checkout could
# have been either kind, and each service ignores the one that does not name it.
# An order needs this as much as a booking does - a pending order holds its
# products out of the shop, so a payment that never arrives has to release them.
Pay::Webhooks.delegator.subscribe "paddle_billing.transaction.payment_failed" do |event|
  BookingPaymentFailureService.call(event: event, status: :payment_failed)
  OrderPaymentFailureService.call(event: event, status: :payment_failed)
end

Pay::Webhooks.delegator.subscribe "paddle_billing.transaction.canceled" do |event|
  BookingPaymentFailureService.call(event: event, status: :canceled)
  OrderPaymentFailureService.call(event: event, status: :canceled)
end
