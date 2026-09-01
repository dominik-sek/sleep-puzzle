# Shared lookup for the paddle_billing.transaction.* webhooks that act on
# something we saved before opening the checkout - a booking, an order.
#
# `event` is the `data` object of the webhook, rehydrated by
# Pay::Webhook#rehydrated_event into a nested InheritableOptions.
#
# Subclasses say what the transaction was expected to pay for by declaring the
# model and the custom_data key that names it. Everything else - the "is this
# really the buyer" check especially - is the same either way and lives here, so
# there is one place to get it right.
class PaddleTransactionService < ApplicationService
  def initialize(event:)
    @event = event
  end

  private

  attr_reader :event

  # What this webhook is expected to have paid for. Both are declared by the
  # subclass; the base class never guesses.
  def model
    raise NotImplementedError, "#{self.class} must declare the model it acts on"
  end

  def custom_data_key
    raise NotImplementedError, "#{self.class} must declare its custom_data key"
  end

  # nil whenever the event can't be tied to a record we're willing to act on
  def record
    @record ||= find_record
  end

  def find_record
    id = event.custom_data&.public_send(custom_data_key)
    return log("no #{custom_data_key} in custom_data") if id.blank?

    found = model.find_by(id: id)
    return log("#{label} #{id} not found") if found.nil?

    # custom_data is set in the browser, so a tampered checkout could name someone
    # else's record - only the customer Paddle actually charged may act on it.
    return log("#{label} #{found.id} does not belong to Paddle customer #{event.customer_id}") unless payer?(found)

    found
  end

  def payer?(found)
    pay_customer = Pay::Customer.find_by(processor: :paddle_billing, processor_id: event.customer_id)
    pay_customer.present? && pay_customer.owner == found.user
  end

  def label
    model.name.downcase
  end

  def transaction_id
    event.id
  end

  def log(message)
    Rails.logger.warn("[paddle] transaction #{transaction_id}: #{message}")
    nil
  end
end
