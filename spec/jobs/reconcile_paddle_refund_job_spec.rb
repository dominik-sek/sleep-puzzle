require "rails_helper"

RSpec.describe ReconcilePaddleRefundJob do
  let(:user) { User.create!(email: "legacy-refund@example.com", password: "password123") }
  let(:order) { user.orders.create!(status: :paid, paddle_transaction_id: "txn_legacy", order_items: [ OrderItem.new(product: create_product(paddle_price_id: "pri_new")) ]) }
  let(:transaction) { Paddle::Transaction.new(id: "txn_legacy", customer_id: "ctm_legacy", details: {
    totals: { grand_total: "2500" }, line_items: [ { id: "txnitm_legacy", price_id: "pri_old", totals: { total: "2500" } } ]
  }) }

  before do
    Pay::Customer.create!(owner: user, processor: :paddle_billing, processor_id: "ctm_legacy")
    PaddleAdjustment.create!(paddle_id: "adj_legacy", transaction_id: "txn_legacy", customer_id: "ctm_legacy", action: "refund", status: "approved",
      paddle_updated_at: Time.current, payload: { type: "partial", totals: { total: "2500" }, items: [ { item_id: "txnitm_legacy", type: "full" } ] })
    allow(Paddle::Transaction).to receive(:retrieve).with(id: "txn_legacy").and_return(transaction)
  end

  it "recovers original transaction lines without backfilling consent or playback" do
    described_class.perform_now(order.paddle_transaction_id)
    item = order.order_items.sole.reload
    expect(item.paddle_transaction_item_id).to eq("txnitm_legacy")
    expect(item.refunded_at).to be_present
    expect(item.first_played_at).to be_nil
    expect(order.reload.consent_accepted_at).to be_nil
    expect(order.legal_snapshot).to eq({})
  end

  it "retries an unavailable Paddle API while retaining the approved adjustment" do
    allow(Paddle::Transaction).to receive(:retrieve).and_raise(Faraday::ConnectionFailed, "offline")
    expect { described_class.perform_now(order.paddle_transaction_id) }.to have_enqueued_job(described_class)
    expect(order.order_items.sole.refunded_at).to be_nil
    expect(PaddleAdjustment.sole.status).to eq("approved")
  end

  it "rejects a transaction returned for another payer" do
    transaction.customer_id = "ctm_someone_else"
    expect { described_class.perform_now(order.paddle_transaction_id) }.to raise_error(PaddleTransactionSnapshotService::InvalidTransaction)
    expect(order.order_items.sole.refunded_at).to be_nil
  end

  it "reconciles a purchase linked after the adjustment was recorded" do
    order.order_items.sole.update!(paddle_transaction_item_id: "txnitm_legacy")
    order.update!(paddle_transaction_snapshot: PaddleTransactionSnapshotService.snapshot(transaction))
    described_class.perform_now(order.paddle_transaction_id)
    expect(order.order_items.sole.reload.refunded_at).to be_present
    expect(Paddle::Transaction).not_to have_received(:retrieve)
  end
end
