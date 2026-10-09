require "rails_helper"

RSpec.describe PaddleRefundService do
  let(:user) { User.create!(email: "refund@example.com", password: "password123") }
  let(:product) { create_product }
  let(:order) { user.orders.create!(status: :paid, paddle_transaction_id: "txn_refund", order_items: [ OrderItem.new(product: product, paddle_price_id: "pri_456", paddle_transaction_item_id: "txnitm_story") ]) }

  before { Pay::Customer.create!(owner: user, processor: :paddle_billing, processor_id: "ctm_refund") }

  def refund(id: "adj_refund", status: "approved", type: "full", amount: "2500", customer: "ctm_refund", updated_at: Time.current)
    payload = {
      id: id, action: "refund", status: status, type: type,
      transaction_id: "txn_refund", customer_id: customer,
      updated_at: updated_at.iso8601,
      totals: { total: amount }, currency_code: "PLN",
      items: [ { item_id: "txnitm_story", type: "partial", totals: { total: amount } } ]
    }
    Pay::Webhook.new(processor: "paddle_billing", event_type: "adjustment.created",
      event: { "data" => payload.deep_stringify_keys }).rehydrated_event
  end

  it "revokes only the refunded purchase and handles duplicate delivery" do
    order
    other = user.orders.create!(status: :paid, order_items: [ OrderItem.new(product: product) ])
    2.times { described_class.call(event: refund) }
    expect(PaddleAdjustment.count).to eq(1)
    expect(order.order_items.sole.reload.refunded_at).to be_present
    expect(user.purchased?(product)).to be(true)
    expect(other.order_items.sole.refunded_at).to be_nil
  end

  it "removes access when the only purchase is fully refunded" do
    order
    described_class.call(event: refund)
    expect(user.purchased?(product)).to be(false)
    expect(order.reload).to be_paid
    expect(order.refund_state).to eq("full")
  end

  it "keeps access for pending, rejected and partial monetary refunds" do
    order
    described_class.call(event: refund(status: "pending_approval"))
    expect(order.refund_state).to eq("pending_approval")
    described_class.call(event: refund(status: "rejected", updated_at: 1.minute.from_now))
    described_class.call(event: refund(id: "adj_partial", type: "partial", amount: "100"))
    expect(order.refund_state).to eq("partial")
    expect(user.purchased?(product)).to be(true)
  end

  it "does not let an older pending event undo approval" do
    order
    described_class.call(event: refund)
    described_class.call(event: refund(status: "pending_approval", updated_at: 1.minute.ago))
    expect(PaddleAdjustment.sole.status).to eq("approved")
    expect(PaddleAdjustment.sole.events.map { |entry| entry["status"] }).to eq(%w[approved pending_approval])
    expect(user.purchased?(product)).to be(false)
  end

  it "revokes only a fully returned product in a multi-product partial adjustment" do
    second = create_product(name: "Drugie nagranie", paddle_price_id: "pri_second")
    other_item = order.order_items.create!(product: second, paddle_transaction_item_id: "txnitm_other")
    payload = refund(type: "partial").to_h.deep_stringify_keys
    payload["items"].first["type"] = "full"
    described_class.call(event: payload)
    expect(order.order_items.find_by(product: product).refunded_at).to be_present
    expect(other_item.reload.refunded_at).to be_nil
    expect(order.refund_state).to eq("partial")
  end

  it "refuses adjustments belonging to another payer" do
    order
    described_class.call(event: refund(customer: "ctm_someone_else"))
    expect(user.purchased?(product)).to be(true)
    expect(order.refund_state).to eq("none")
  end

  it "accumulates partial refunds until the product is fully refunded" do
    order.update!(paddle_transaction_snapshot: { details: { line_items: [ { id: "txnitm_story", totals: { total: "2500" } } ] } })
    described_class.call(event: refund(id: "adj_first", type: "partial", amount: "1000"))
    expect(user.purchased?(product)).to be(true)
    described_class.call(event: refund(id: "adj_second", type: "partial", amount: "1500"))
    expect(user.purchased?(product)).to be(false)
  end

  it "applies an adjustment received before transaction completion" do
    pending = user.orders.create!(order_items: [ OrderItem.new(product: product, paddle_price_id: "pri_456") ])
    product.update!(paddle_price_id: "pri_changed")
    expect(pending.paddle_items).to eq([ { priceId: "pri_456", quantity: 1 } ])
    described_class.call(event: refund)
    event = ActiveSupport::InheritableOptions.new(id: "txn_refund", customer_id: "ctm_refund",
      custom_data: ActiveSupport::InheritableOptions.new(order_id: pending.id.to_s),
      details: { line_items: [ { id: "txnitm_story", price_id: "pri_456" } ] })
    OrderConfirmationService.call(event: event)
    OrderConfirmationService.call(event: event)
    expect(pending.reload).to be_paid
    expect(pending.order_items.sole.refunded_at).to be_present
    expect(pending.order_items.sole.paddle_transaction_item_id).to eq("txnitm_story")
    expect(user.purchased?(product)).to be(false)
  end

  it "records a booking refund without canceling or deleting its event" do
    booking = user.bookings.create!(name: "Marta", email: user.email, package: create_package,
      starts_at: 3.days.from_now, status: :confirmed, calendar_event_id: "google_event", paddle_transaction_id: "txn_refund")
    described_class.call(event: refund)
    expect(booking.reload).to be_confirmed
    expect(booking.calendar_event_id).to eq("google_event")
    expect(booking.refund_state).to eq("full")
  end
end
