require "rails_helper"

RSpec.describe "Admin booking changes", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  let(:admin) { User.create!(email: "admin@example.com", password: "password123", admin: true) }
  let(:user) { User.create!(email: "client@example.com", password: "password123") }
  let(:package) { create_package }
  let(:slot) { SlotComparatorService.call(settings: ConsultationSetting.current).first.begin }
  let(:booking) { user.bookings.create!(name: "Marta", email: user.email, package: package, starts_at: slot, status: :confirmed, confirmed_at: Time.current, consent_accepted_at: Time.current, paddle_transaction_id: "txn_booking") }

  before do
    ConsultationSetting.current.update!(local_availability: true)
    sign_in admin
  end

  def fields(received_at: Time.current, initiator: "customer")
    { booking: { received_at: received_at.iso8601, initiator: initiator, reason: "Rezygnacja klienta" } }
  end

  it "releases a timely cancellation immediately without a Paddle refund" do
    booking
    travel_to slot - 24.hours do
      patch cancel_admin_booking_path(booking), params: fields
      expect(response).to redirect_to(admin_booking_path(booking))
      expect(booking.reload).to be_canceled
      expect(booking.canceled_at).to be_present
      expect(booking.paddle_transaction_id).to eq("txn_booking")
      expect(booking.refund_state).to eq("none")
      expect(booking.booking_changes.sole).to be_timely
      expect(SlotComparatorService.call.map(&:begin)).to include(slot)
      expect(SyncBookingCalendarJob).to have_been_enqueued.with(booking.id)
    end
  end

  it "records late cancellation without automatic deductions" do
    booking
    travel_to slot - 23.hours do
      patch cancel_admin_booking_path(booking), params: fields
      expect(response).to redirect_to(admin_booking_path(booking))
      expect(booking.reload).to be_canceled
      expect(booking.booking_changes.sole).not_to be_timely
      expect(booking.refund_state).to eq("none")
    end
  end

  it "records absence after the appointment while preserving payment history" do
    original_slot = booking.starts_at
    travel_to original_slot + 2.hours do
      patch cancel_admin_booking_path(booking), params: fields
      expect(booking.reload).to be_canceled
      expect(booking.booking_changes.sole).not_to be_timely
      expect(booking.confirmed_at).to be_present
    end
  end

  it "records cancellation by Karola separately from refund processing" do
    patch cancel_admin_booking_path(booking), params: fields(initiator: "owner")
    expect(booking.booking_changes.sole.initiator).to eq("owner")
    expect(PaddleAdjustment.count).to eq(0)
  end

  it "shows a paid cancellation separately from its refund state to the customer" do
    patch cancel_admin_booking_path(booking), params: fields
    sign_in user
    get booking_path(booking)
    expect(response.body).to include("Konsultacja została odwołana", "Opłacona", "Stan zwrotu", "Brak zwrotu")
  end

  it "flags a refund of an active consultation on the admin list" do
    Pay::Customer.create!(owner: user, processor: :paddle_billing, processor_id: "ctm_booking")
    PaddleAdjustment.create!(paddle_id: "adj_booking", transaction_id: booking.paddle_transaction_id,
      customer_id: "ctm_booking", action: "refund", status: "approved", paddle_updated_at: Time.current, payload: { type: "full" })
    get admin_bookings_path
    expect(response.body).to include("Zwrot pełny", "Sprawdź aktywną rezerwację")
    expect(booking.reload).to be_confirmed
  end

  it "rejects moving an appointment into the first 14 days without saved consent" do
    booking.update!(consent_accepted_at: nil)
    old = booking.starts_at
    target = SlotComparatorService.call.map(&:begin).find { |start| start != old && start < 14.days.from_now }
    patch reschedule_admin_booking_path(booking), params: fields.deep_merge(booking: { starts_at: target.iso8601 })
    expect(response).to have_http_status(:unprocessable_entity)
    expect(booking.reload.starts_at).to eq(old)
    expect(booking.booking_changes.count).to eq(0)
  end

  it "does not cancel twice or let a late payment confirmation resurrect a canceled booking" do
    booking.update!(paddle_transaction_id: nil)
    patch cancel_admin_booking_path(booking), params: fields
    patch cancel_admin_booking_path(booking), params: fields
    expect(response).to have_http_status(:unprocessable_entity)
    expect(booking.booking_changes.count).to eq(1)
    expect(booking.confirm_payment!("txn_late")).to be(true)
    expect(booking.reload).to be_canceled
  end

  it "moves a paid booking to an available slot, preserving payment and recording both dates" do
    old = booking.starts_at
    target = SlotComparatorService.call.map(&:begin).find { |start| start != old }
    patch reschedule_admin_booking_path(booking), params: fields.deep_merge(booking: { starts_at: target.iso8601 })
    expect(response).to redirect_to(admin_booking_path(booking))
    expect(booking.reload.starts_at).to eq(target)
    expect(booking.paddle_transaction_id).to eq("txn_booking")
    expect(booking.booking_changes.sole.previous_starts_at).to eq(old)
    expect(SlotComparatorService.call.map(&:begin)).to include(old)
    expect(SlotComparatorService.call.map(&:begin)).not_to include(target)
  end

  it "rejects an occupied new slot without changing either booking" do
    old = booking.starts_at
    target = SlotComparatorService.call.first.begin
    user.bookings.create!(name: "Inna", email: user.email, package: package, starts_at: target, status: :confirmed)
    patch reschedule_admin_booking_path(booking), params: fields.deep_merge(booking: { starts_at: target.iso8601 })
    expect(response).to have_http_status(:unprocessable_entity)
    expect(booking.reload.starts_at).to eq(old)
    expect(booking.booking_changes.count).to eq(0)
  end

  it "protects cancellation and settlement actions from customers" do
    sign_in user
    patch cancel_admin_booking_path(booking), params: fields
    expect(response).to redirect_to(root_path)
    patch settlement_admin_booking_path(booking), params: { booking: { settlement_notes: "not authorized" } }
    expect(response).to redirect_to(root_path)
    expect(booking.reload).to be_confirmed
  end

  it "appends settlement rationale with an audit timestamp and author" do
    2.times { patch settlement_admin_booking_path(booking), params: { booking: { settlement_notes: "Analiza ankiety — wykonana" } } }
    expect(booking.reload.settlement_notes.scan("Analiza ankiety").size).to eq(2)
    expect(booking.settlement_notes).to include(admin.email)
  end
end
