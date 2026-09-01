require 'rails_helper'

RSpec.describe ReleaseAbandonedOrdersJob do
  let(:user) { User.create!(email: "customer@example.com", password: "password123") }
  let(:product) { create_product(name: "Bajka o sowie") }

  def pending_order(created_at:)
    user.orders.create!(
      status: :pending,
      created_at: created_at,
      order_items: [ OrderItem.new(product: product) ]
    )
  end

  # closing the tab fires no webhook, and without this the file is locked forever
  it "releases a checkout nobody came back to" do
    order = pending_order(created_at: 2.hours.ago)

    described_class.perform_now

    expect(order.reload).to be_canceled
    expect(user.claimed?(product)).to be(false)
  end

  it "leaves a payment that may still be in flight alone" do
    order = pending_order(created_at: 5.minutes.ago)

    described_class.perform_now

    expect(order.reload).to be_pending
  end

  it "leaves an order Paddle has already named a transaction for alone" do
    order = pending_order(created_at: 2.hours.ago)
    order.update!(paddle_transaction_id: "txn_1")

    described_class.perform_now

    expect(order.reload).to be_pending
  end

  # canceled rather than destroyed, so a late completion still finds a row
  it "keeps the row so a late webhook can still mark it paid" do
    order = pending_order(created_at: 2.hours.ago)

    described_class.perform_now
    order.reload.mark_paid!(transaction_id: "txn_1")

    expect(order.reload).to be_paid
  end
end
