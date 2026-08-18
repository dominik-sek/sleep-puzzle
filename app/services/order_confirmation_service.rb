# Marks the order a completed Paddle transaction paid for.
#
# Subscribed to the same event as BookingConfirmationService: both run for every
# paddle_billing.transaction.completed, and each ignores the ones that do not
# name it — a booking checkout carries booking_id in custom_data, an order
# carries order_id, so the lookup in PaddleTransactionService returns nil for the
# other one and logs why.
class OrderConfirmationService < PaddleTransactionService
  def call
    # Paddle redelivers on any non-2xx, and Pay retries the job, so the same
    # transaction can arrive more than once
    return if Order.exists?(paddle_transaction_id: transaction_id)

    # money has changed hands and there is nothing to credit it to — an abandoned
    # checkout deletes its order, so a completion arriving after that needs a human
    if order.nil?
      Rails.logger.error("[paddle] transaction #{transaction_id} completed but no order could be matched") if order_checkout?
      return
    end

    if order.mark_paid!(transaction_id: transaction_id)
      Rails.logger.info("Marked order #{order.id} paid from Paddle transaction #{transaction_id}")
    end

    order
  end

  private

  def model = Order
  def custom_data_key = :order_id
  alias_method :order, :record

  # Distinguishes "this transaction was never an order" — a booking checkout,
  # which this service simply is not for — from "an order was named and could not
  # be found", which is money nobody can account for.
  def order_checkout?
    event.custom_data&.order_id.present?
  end
end
