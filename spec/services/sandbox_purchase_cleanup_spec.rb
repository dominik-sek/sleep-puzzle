require "rails_helper"

RSpec.describe SandboxPurchaseCleanup do
  let(:user) { User.create!(email: "sandbox-cleanup@example.com", password: "password123", admin: true) }
  let(:other) { User.create!(email: "other-cleanup@example.com", password: "password123") }
  let(:product) { create_product }
  let(:package) { create_package }
  let!(:customer) { Pay::Customer.create!(owner: user, processor: :paddle_billing, processor_id: "ctm_test", default: true) }
  let!(:order) { user.orders.create!(status: :paid, paddle_transaction_id: "txn_audio", order_items: [ OrderItem.new(product: product, first_played_at: Time.current) ]) }
  let!(:booking) { user.bookings.create!(name: "Test", email: user.email, package: package, starts_at: 1.day.from_now, calendar_event_id: "test_event", paddle_transaction_id: "txn_booking") }
  let!(:change) { booking.booking_changes.create!(kind: "rescheduled", initiator: "customer", received_at: 1.hour.ago, previous_starts_at: 2.days.from_now, reason: "Test", admin: user) }
  let!(:charge) { Pay::Charge.create!(customer: customer, processor_id: "txn_audio", amount: 1000) }
  let!(:payment_method) { Pay::PaymentMethod.create!(customer: customer, processor_id: "paymtd_test") }
  let!(:adjustment) do
    PaddleAdjustment.create!(paddle_id: "adj_test", customer_id: customer.processor_id, transaction_id: "txn_audio",
      action: "refund", status: "approved", paddle_updated_at: Time.current, payload: {}, events: [])
  end
  let!(:webhook) do
    Pay::Webhook.create!(processor: :paddle_billing, event_type: "adjustment.updated",
      event: { data: { id: "adj_test", transaction_id: "txn_audio", customer_id: customer.processor_id } })
  end
  subject(:cleanup) { described_class.new(email: user.email) }

  before do
    allow(Pay::PaddleBilling).to receive(:environment).and_return("sandbox")
    allow(Paddle::Customer).to receive(:retrieve).with(id: "ctm_test").and_return(Paddle::Customer.new(id: "ctm_test"))
    allow(Paddle::Transaction).to receive(:retrieve) { |id:| Paddle::Transaction.new(id: id, customer_id: "ctm_test") }
    allow(BookingCalendarService).to receive(:call).with(booking: booking, strict: true)
      .and_return(instance_double(BookingCalendarService, release: true))
  end

  def purge
    cleanup.purge!(confirmation: cleanup.preview.fetch(:confirmation))
  end

  it "previews only this account without deleting records or contacting external services" do
    before = [ User.count, Order.count, Booking.count, Pay::Charge.count ]
    preview = cleanup.preview
    expect(preview[:email]).to eq(user.email)
    expect(preview[:counts]).to include(orders: 1, bookings: 1, booking_changes: 1, order_items: 1, pay_charges: 1, paddle_adjustments: 1, pay_webhooks: 1)
    expect([ User.count, Order.count, Booking.count, Pay::Charge.count ]).to eq(before)
    expect(Paddle::Transaction).not_to have_received(:retrieve)
    expect(BookingCalendarService).not_to have_received(:call)
  end

  it "purges the purchased test data and history but preserves the user, catalogue and another buyer" do
    other_customer = Pay::Customer.create!(owner: other, processor: :paddle_billing, processor_id: "ctm_other", default: true)
    other_charge = Pay::Charge.create!(customer: other_customer, processor_id: "txn_other", amount: 1000)
    other_order = other.orders.create!(status: :paid, order_items: [ OrderItem.new(product: product) ])
    other_booking = other.bookings.create!(name: "Other", email: other.email, package: package, starts_at: 2.days.from_now)
    other_adjustment = PaddleAdjustment.create!(paddle_id: "adj_other", customer_id: "ctm_other", transaction_id: "txn_other",
      action: "refund", status: "approved", paddle_updated_at: Time.current)
    counts = purge
    expect(counts[:bookings]).to eq(1)
    expect(user.reload).to be_admin
    expect(user.orders).to be_empty
    expect(user.bookings).to be_empty
    expect(BookingChange.exists?(change.id)).to be(false)
    expect(OrderItem.where(order_id: order.id)).to be_empty
    expect(Pay::Charge.exists?(charge.id)).to be(false)
    expect(Pay::PaymentMethod.exists?(payment_method.id)).to be(false)
    expect(Pay::Webhook.exists?(webhook.id)).to be(false)
    expect(PaddleAdjustment.exists?(adjustment.id)).to be(false)
    [ customer, product, package, other_order, other_booking, other_charge, other_adjustment ].each { |record| expect(record.class.exists?(record.id)).to be(true) }
    expect(BookingCalendarService).to have_received(:call).with(booking: booking, strict: true)
  end

  it "requires the fingerprint of the reviewed scope" do
    expect { cleanup.purge!(confirmation: "incorrect") }.to raise_error(described_class::UnsafeCleanup, /CONFIRM/)
    expect(Order.exists?(order.id)).to be(true)
    expect(BookingCalendarService).not_to have_received(:call)
  end

  it "invalidates confirmation when a purchase is added after preview" do
    confirmation = cleanup.preview.fetch(:confirmation)
    user.orders.create!(order_items: [ OrderItem.new(product: create_product) ])
    expect { cleanup.purge!(confirmation: confirmation) }.to raise_error(described_class::UnsafeCleanup, /Zakres/)
    expect(user.orders.count).to eq(2)
  end

  it "invalidates confirmation after a booking changes" do
    confirmation = cleanup.preview.fetch(:confirmation)
    booking.update!(status: :confirmed)
    expect { cleanup.purge!(confirmation: confirmation) }.to raise_error(described_class::UnsafeCleanup, /Zakres/)
  end

  it "refuses a live configuration" do
    allow(Pay::PaddleBilling).to receive(:environment).and_return("live")
    expect { cleanup.preview }.to raise_error(described_class::UnsafeCleanup, /sandbox/)
    expect { cleanup.purge!(confirmation: "anything") }.to raise_error(described_class::UnsafeCleanup, /sandbox/)
  end

  it "does not delete anything if a stored transaction cannot be found in sandbox" do
    allow(Paddle::Transaction).to receive(:retrieve).with(id: "txn_booking").and_raise(StandardError, "not found in sandbox")
    expect { purge }.to raise_error(StandardError, /not found/)
    expect(user.orders.count).to eq(1)
    expect(user.bookings.count).to eq(1)
    expect(BookingCalendarService).not_to have_received(:call)
  end

  it "refuses a sandbox transaction belonging to a different customer" do
    allow(Paddle::Transaction).to receive(:retrieve).with(id: "txn_audio").and_return(Paddle::Transaction.new(id: "txn_audio", customer_id: "ctm_other"))
    expect { purge }.to raise_error(described_class::UnsafeCleanup, /nie należy/)
    expect(Order.exists?(order.id)).to be(true)
  end

  it "preserves database records and event identifiers if Google deletion fails" do
    allow(BookingCalendarService).to receive(:call).and_call_original
    allow(GoogleCalendarService).to receive(:call).and_raise(GoogleCalendarService::NotConnected)
    expect { purge }.to raise_error(GoogleCalendarService::NotConnected)
    expect(booking.reload.calendar_event_id).to eq("test_event")
    expect(Order.exists?(order.id)).to be(true)
    expect(BookingChange.exists?(change.id)).to be(true)
    expect(Pay::Webhook.exists?(webhook.id)).to be(true)
  end

  it "does not delete subscriptions or silently cancel them" do
    Pay::Subscription.create!(customer: customer, name: "default", processor_id: "sub_test", processor_plan: "pri_test", status: "active")
    expect { purge }.to raise_error(described_class::UnsafeCleanup, /subskrypcje/)
    expect(Order.exists?(order.id)).to be(true)
  end
end
