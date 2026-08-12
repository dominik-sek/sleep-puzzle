# Booking side effects for the Paddle transaction webhooks.
#
# ActiveSupport::Notifications runs these before Pay's own charge sync, so don't
# expect a Pay::Charge to exist here yet. If that later sync raises (Paddle API
# down, transaction not yet queryable) the Pay::Webhook row survives and the job
# retries the whole chain — which is why these services have to be idempotent
# rather than assume they run once.
#
# Pay's webhook controller silently drops events nothing is subscribed to, so an
# event type has to be listed here before it is even stored.
Pay::Webhooks.delegator.subscribe "paddle_billing.transaction.completed" do |event|
  BookingConfirmationService.call(event: event)
end

Pay::Webhooks.delegator.subscribe "paddle_billing.transaction.payment_failed" do |event|
  BookingPaymentFailureService.call(event: event, status: :payment_failed)
end

Pay::Webhooks.delegator.subscribe "paddle_billing.transaction.canceled" do |event|
  BookingPaymentFailureService.call(event: event, status: :canceled)
end
