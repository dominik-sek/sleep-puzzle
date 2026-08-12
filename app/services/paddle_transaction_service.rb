# Shared lookup for the paddle_billing.transaction.* webhooks that act on a booking.
#
# `event` is the `data` object of the webhook, rehydrated by
# Pay::Webhook#rehydrated_event into a nested InheritableOptions.
class PaddleTransactionService < ApplicationService
  def initialize(event:)
    @event = event
  end

  private

  attr_reader :event

  # nil whenever the event can't be tied to a booking we're willing to act on
  def booking
    @booking ||= find_booking
  end

  def find_booking
    id = event.custom_data&.booking_id
    return log("no booking_id in custom_data") if id.blank?

    found = Booking.find_by(id: id)
    return log("booking #{id} not found") if found.nil?

    # custom_data is set in the browser, so a tampered checkout could name someone
    # else's booking — only the customer Paddle actually charged may act on it.
    return log("booking #{found.id} does not belong to Paddle customer #{event.customer_id}") unless payer?(found)

    found
  end

  def payer?(booking)
    pay_customer = Pay::Customer.find_by(processor: :paddle_billing, processor_id: event.customer_id)
    pay_customer.present? && pay_customer.owner == booking.user
  end

  def transaction_id
    event.id
  end

  def log(message)
    Rails.logger.warn("[paddle] transaction #{transaction_id}: #{message}")
    nil
  end
end
