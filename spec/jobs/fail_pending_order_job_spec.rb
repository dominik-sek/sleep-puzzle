require 'rails_helper'

RSpec.describe FailPendingOrderJob do
  let(:user) { User.create!(email: "customer@example.com", password: "password123") }
  let(:product) { create_product(name: "Bajka o sowie") }
  let(:order) do
    user.orders.create!(status: :pending, order_items: [ OrderItem.new(product: product) ])
  end

  it "flips a still-pending order and puts its product back on sale" do
    described_class.perform_now(order.id, "payment_failed")

    expect(order.reload).to be_payment_failed
    expect(user.claimed?(product)).to be(false)
  end

  # the retry went through in the meantime
  it "leaves a paid order alone" do
    order.mark_paid!(transaction_id: "txn_1")

    described_class.perform_now(order.id, "canceled")

    expect(order.reload).to be_paid
  end

  it "survives an order deleted by the buyer closing the overlay" do
    id = order.id
    order.destroy!

    expect { described_class.perform_now(id, "canceled") }.not_to raise_error
  end
end
