require "rails_helper"

RSpec.describe BookingPaymentCheckService do
  let(:user) { User.create!(email: "payment-check@example.com", password: "password123") }
  let(:booking) { user.bookings.create!(package: create_package, name: "Marta", email: user.email, starts_at: 1.month.from_now) }
  subject(:check) { described_class.call(booking: booking) }

  def transaction(status: "draft", payments: [], token: booking.token, created_at: booking.created_at.iso8601(6), **attributes)
    Paddle::Transaction.new({
      "id" => "txn_current", "status" => status, "created_at" => created_at,
      "custom_data" => { "booking_id" => booking.id.to_s, "booking_token" => token },
      "payments" => payments.map { |status| { "status" => status } }
    }.merge(attributes.stringify_keys))
  end

  before do
    Pay::Customer.create!(owner: user, processor: :paddle_billing, processor_id: "ctm_check", default: true)
    allow(Paddle::Transaction).to receive(:list).and_return([])
  end

  %w[draft ready canceled].each do |status|
    it "releases an unpaid #{status} checkout without claiming payment" do
      allow(Paddle::Transaction).to receive(:list).and_return([ transaction(status: status) ])
      expect(check).to be_unpaid
      expect(check).not_to be_paid
    end
  end

  %w[paid completed].each do |status|
    it "retains a #{status} payment before the webhook arrives" do
      allow(Paddle::Transaction).to receive(:list).and_return([ transaction(status: status) ])
      expect(check).to be_paid
      expect(check).not_to be_unpaid
    end
  end

  it "does not call an unknown, billed or past-due transaction paid or safe to delete" do
    allow(Paddle::Transaction).to receive(:list).and_return(%w[new_state billed past_due].map { |status| transaction(status: status) })
    expect(check).not_to be_paid
    expect(check).not_to be_unpaid
  end

  it "protects a captured payment even when the transaction status still says ready" do
    allow(Paddle::Transaction).to receive(:list).and_return([ transaction(status: "ready", payments: [ "error", "captured" ]) ])
    expect(check).to be_paid
    expect(check).not_to be_unpaid
  end

  %w[authorized authorized_flagged pending_no_action_required created unknown future_state].each do |status|
    it "retains a #{status} attempt without claiming it was paid" do
      allow(Paddle::Transaction).to receive(:list).and_return([ transaction(status: "ready", payments: [ status ]) ])
      expect(check).not_to be_paid
      expect(check).not_to be_unpaid
    end
  end

  it "reports a declined card and permits release" do
    allow(Paddle::Transaction).to receive(:list).and_return([ transaction(status: "ready", payments: [ "error" ]) ])
    expect(check).to be_declined
    expect(check).to be_unpaid
  end

  it "ignores a previous checkout with a reused booking id and a different token" do
    allow(Paddle::Transaction).to receive(:list).and_return([ transaction, transaction(status: "completed", token: "previous-booking") ])
    expect(check).not_to be_paid
    expect(check).to be_unpaid
  end

  it "ignores old legacy transactions but still recognizes a current legacy payment" do
    allow(Paddle::Transaction).to receive(:list).and_return([ transaction(status: "completed", token: nil, created_at: 1.day.ago.iso8601) ])
    expect(check).not_to be_paid
    expect(check).to be_unpaid
    fresh = described_class.call(booking: booking)
    allow(Paddle::Transaction).to receive(:list).and_return([ transaction(status: "completed", token: nil) ])
    expect(fresh).to be_paid
  end

  it "reads further pages instead of missing a paid checkout" do
    unrelated = 30.times.map { |i| transaction(id: "txn_#{i}", custom_data: nil) }
    allow(Paddle::Transaction).to receive(:list).and_return(unrelated, [ transaction(status: "completed") ])
    expect(check).to be_paid
    expect(Paddle::Transaction).to have_received(:list).with(hash_including(customer_id: "ctm_check", after: "txn_29", "created_at[GTE]": booking.created_at.iso8601))
  end

  it "does not claim either payment or nonpayment when Paddle fails" do
    allow(Paddle::Transaction).to receive(:list).and_raise(StandardError, "unreachable")
    expect(check).not_to be_paid
    expect(check).not_to be_unpaid
  end
end
