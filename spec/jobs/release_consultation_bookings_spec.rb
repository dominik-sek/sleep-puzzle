require "rails_helper"

RSpec.describe "Releasing local consultation reservations" do
  include ActiveSupport::Testing::TimeHelpers

  before do
    travel_to Time.zone.parse("2026-10-05 07:00")
    ConsultationSetting.current.update!(local_availability: true)
    @user = User.create!(email: "release@example.com", password: "password123")
    @booking = Booking.create!(user: @user, package: create_package, name: "Marta", email: @user.email,
      starts_at: Time.zone.parse("2026-10-12 08:15"), created_at: 2.hours.ago, calendar_event_id: "old-google-copy")
    allow(GoogleCalendarService).to receive(:call).and_raise(GoogleCalendarService::NotConnected)
    allow(BookingPaymentCheckService).to receive(:call).and_return(instance_double(BookingPaymentCheckService, unpaid?: true))
  end
  after { travel_back }

  def available
    SlotComparatorService.call.map(&:begin)
  end

  it "releases abandoned pending appointments despite a Google outage" do
    expect(available).not_to include(@booking.starts_at)
    ReleaseAbandonedBookingsJob.perform_now
    expect(@booking.reload).to be_canceled
    expect(available).to include(@booking.starts_at)
  end

  it "releases failed payments despite a Google outage" do
    ReleaseFailedBookingJob.perform_now(@booking.id, "payment_failed")
    expect(@booking.reload).to be_payment_failed
    expect(available).to include(@booking.starts_at)
  end

  it "retains a pending appointment when Paddle cannot confirm nonpayment" do
    allow(BookingPaymentCheckService).to receive(:call).and_return(instance_double(BookingPaymentCheckService, unpaid?: false))
    ReleaseAbandonedBookingsJob.perform_now
    expect(@booking.reload).to be_pending
    expect(available).not_to include(@booking.starts_at)
  end

  it "never releases a confirmed booking from an old pending object" do
    stale = Booking.find(@booking.id)
    @booking.confirm_payment!("txn_confirmed")
    expect(stale.fail_payment!(:canceled)).to be false
    ReleaseAbandonedBookingsJob.perform_now
    ReleaseFailedBookingJob.perform_now(@booking.id, "payment_failed")
    expect(@booking.reload).to be_confirmed
    expect(available).not_to include(@booking.starts_at)
  end

  it "preserves existing consultation times when the schedule changes" do
    before = @booking.attributes.slice("starts_at", "ends_at", "status")
    setting = ConsultationSetting.current
    weekly = setting.weekly_slots.find_by!(weekday: 1)
    setting.with_lock do
      setting.update!(weekly_slots_attributes: [ { id: weekly.id, time_of_day: "11:00" } ])
    end
    expect(@booking.reload.attributes.slice("starts_at", "ends_at", "status")).to eq(before)
  end
end
