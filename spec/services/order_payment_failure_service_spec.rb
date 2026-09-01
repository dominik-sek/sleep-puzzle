require 'rails_helper'

RSpec.describe OrderPaymentFailureService do
  let(:user) { User.create!(email: "customer@example.com", password: "password123") }
  let(:product) { create_product(name: "Bajka o sowie") }
  let(:order) do
    user.orders.create!(status: :pending, order_items: [ OrderItem.new(product: product) ])
  end

  def event(order_id:, customer_id: "ctm_123", id: "txn_1")
    ActiveSupport::InheritableOptions.new(
      id: id,
      customer_id: customer_id,
      custom_data: order_id && ActiveSupport::InheritableOptions.new(order_id: order_id.to_s)
    )
  end

  before { Pay::Customer.create!(owner: user, processor: :paddle_billing, processor_id: "ctm_123") }

  # a decline leaves the buyer in the checkout with another card to try, and that
  # same transaction can still complete
  it "waits out the grace period on a decline" do
    expect {
      described_class.call(event: event(order_id: order.id), status: :payment_failed)
    }.to have_enqueued_job(FailPendingOrderJob)
      .with(order.id, "payment_failed")
      .at(a_value_within(1.minute).of(15.minutes.from_now))

    expect(order.reload).to be_pending
  end

  it "releases a cancellation without waiting" do
    expect {
      described_class.call(event: event(order_id: order.id), status: :canceled)
    }.to have_enqueued_job(FailPendingOrderJob).with(order.id, "canceled")
  end

  it "leaves an order that is already paid alone" do
    order.mark_paid!(transaction_id: "txn_0")

    expect {
      described_class.call(event: event(order_id: order.id), status: :canceled)
    }.not_to have_enqueued_job(FailPendingOrderJob)
  end

  # a booking checkout's failure runs through here too and must not match
  it "ignores an event that names no order" do
    expect {
      described_class.call(event: event(order_id: nil), status: :canceled)
    }.not_to have_enqueued_job(FailPendingOrderJob)
  end

  it "refuses an order belonging to a different Paddle customer" do
    expect {
      described_class.call(event: event(order_id: order.id, customer_id: "ctm_999"), status: :canceled)
    }.not_to have_enqueued_job(FailPendingOrderJob)
  end
end
