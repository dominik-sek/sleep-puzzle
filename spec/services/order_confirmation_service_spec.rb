require 'rails_helper'

RSpec.describe OrderConfirmationService do
  let(:user) { User.create!(email: "customer@example.com", password: "password123") }
  let(:product) { create_product(name: "Bajka o sowie") }
  let(:order) do
    user.orders.create!(status: :pending, order_items: [ OrderItem.new(product: product, quantity: 1) ])
  end

  # what Pay::Webhook#rehydrated_event hands the subscriber
  def event(order_id:, customer_id: "ctm_123", id: "txn_1")
    ActiveSupport::InheritableOptions.new(
      id: id,
      customer_id: customer_id,
      custom_data: order_id && ActiveSupport::InheritableOptions.new(order_id: order_id.to_s)
    )
  end

  def link_paddle_customer(owner, processor_id = "ctm_123")
    Pay::Customer.create!(owner: owner, processor: :paddle_billing, processor_id: processor_id)
  end

  it "marks the order paid and records the transaction" do
    link_paddle_customer(user)

    described_class.call(event: event(order_id: order.id))

    expect(order.reload).to be_paid
    expect(order.paddle_transaction_id).to eq("txn_1")
    expect(order.paid_at).to be_present
  end

  # Pay retries the whole chain when its own charge sync raises, so the same
  # transaction arrives more than once
  it "is idempotent across a redelivered event" do
    link_paddle_customer(user)
    described_class.call(event: event(order_id: order.id))
    first_paid_at = order.reload.paid_at

    described_class.call(event: event(order_id: order.id))

    expect(order.reload.paid_at).to eq(first_paid_at)
  end

  # custom_data is set in the browser, so a tampered checkout could name someone
  # else's order
  it "refuses an order that does not belong to the Paddle customer charged" do
    other = User.create!(email: "someone@example.com", password: "password123")
    link_paddle_customer(other)

    described_class.call(event: event(order_id: order.id))

    expect(order.reload).to be_pending
  end

  it "does nothing when the Paddle customer is unknown to us" do
    described_class.call(event: event(order_id: order.id))

    expect(order.reload).to be_pending
  end

  # a booking checkout runs through this subscriber too, and simply is not ours
  it "ignores a transaction that names no order" do
    link_paddle_customer(user)

    expect { described_class.call(event: event(order_id: nil)) }.not_to raise_error
    expect(order.reload).to be_pending
  end

  # an abandoned checkout deletes its order, so a completion arriving after that
  # is money nobody can account for — it has to be loud
  it "logs an error when an order is named but cannot be found" do
    link_paddle_customer(user)
    allow(Rails.logger).to receive(:error)

    described_class.call(event: event(order_id: 999_999))

    expect(Rails.logger).to have_received(:error).with(/no order could be matched/)
  end

  it "stays quiet when the transaction was never an order in the first place" do
    link_paddle_customer(user)
    allow(Rails.logger).to receive(:error)

    described_class.call(event: event(order_id: nil))

    expect(Rails.logger).not_to have_received(:error)
  end
end
