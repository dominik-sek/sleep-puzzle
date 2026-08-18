require 'rails_helper'

# The booking half of the shared PaddleTransactionService lookup. Orders now run
# through the same base class, so this pins down that the booking flow still
# finds its record by booking_id and still refuses one it was not charged for.
RSpec.describe BookingConfirmationService do
  let(:user) { User.create!(email: "customer@example.com", password: "password123") }
  let(:package) { create_package(name: "Szybka ulga") }
  let(:booking) do
    Booking.create!(user: user, package: package, name: "Ala", email: user.email,
                    starts_at: 2.days.from_now, status: :pending)
  end

  before do
    allow(BookingCalendarService).to receive(:call)
      .and_return(instance_double(BookingCalendarService, sync_status: true))
    allow(BookingMailer).to receive(:with).and_return(
      double(confirmed: double(deliver_later: true), new_booking: double(deliver_later: true))
    )
  end

  # what Pay::Webhook#rehydrated_event hands the subscriber
  def event(booking_id:, customer_id: "ctm_123", id: "txn_1")
    ActiveSupport::InheritableOptions.new(
      id: id,
      customer_id: customer_id,
      custom_data: booking_id && ActiveSupport::InheritableOptions.new(booking_id: booking_id.to_s)
    )
  end

  def link_paddle_customer(owner, processor_id = "ctm_123")
    Pay::Customer.create!(owner: owner, processor: :paddle_billing, processor_id: processor_id)
  end

  it "confirms the booking the transaction paid for" do
    link_paddle_customer(user)

    described_class.call(event: event(booking_id: booking.id))

    expect(booking.reload).to be_confirmed
    expect(booking.paddle_transaction_id).to eq("txn_1")
  end

  # custom_data is set in the browser, so a tampered checkout could name someone
  # else's booking
  it "refuses a booking that does not belong to the Paddle customer charged" do
    other = User.create!(email: "someone@example.com", password: "password123")
    link_paddle_customer(other)

    described_class.call(event: event(booking_id: booking.id))

    expect(booking.reload).to be_pending
  end

  # an order checkout runs through this subscriber too, and simply is not ours
  it "ignores a transaction that names no booking" do
    link_paddle_customer(user)

    expect { described_class.call(event: event(booking_id: nil)) }.not_to raise_error
    expect(booking.reload).to be_pending
  end
end
