require "rails_helper"

RSpec.describe SlotComparatorService do
  include ActiveSupport::Testing::TimeHelpers

  let(:settings) { ConsultationSetting.current }
  let(:monday) { Time.zone.parse("2026-10-12 08:15") }

  before do
    travel_to Time.zone.parse("2026-10-05 07:00")
    settings.update!(local_availability: true, minimum_notice_hours: 24)
  end
  after { travel_back }

  def available
    described_class.call(settings: settings).map(&:begin)
  end

  it "preserves the seeded weekly schedule and the public window" do
    expect(settings.weekly_slots.count).to eq(8)
    expect(available).to include(monday)
    expect(available).not_to include(Time.zone.parse("2026-10-05 08:15"))
    expect(available.all? { |time| settings.booking_dates.cover?(time.to_date) }).to be true
  end

  it "uses configured notice and booking window" do
    settings.update!(minimum_notice_hours: 0, booking_window_months: 4)
    expect(available).to include(Time.zone.parse("2026-10-05 08:15"), Time.zone.parse("2027-01-11 08:15"))
  end

  it "blocks partial overlaps but allows touching boundaries" do
    block = ConsultationBlock.create!(starts_at: monday + 89.minutes, ends_at: monday + 2.hours, all_day: false)
    expect(available).not_to include(monday)
    block.update!(starts_at: monday + 90.minutes)
    expect(available).to include(monday)
    block.update!(starts_at: monday - 1.hour, ends_at: monday)
    expect(available).to include(monday)
  end

  it "blocks an inclusive date range across a DST transition" do
    ConsultationBlock.create!(starts_at: Date.new(2026, 10, 23).beginning_of_day, ends_at: Date.new(2026, 10, 27).beginning_of_day)
    expect(available).not_to include(Time.zone.parse("2026-10-23 08:15"), Time.zone.parse("2026-10-26 08:15"))
    expect(available).to include(Time.zone.parse("2026-10-27 08:15"))
  end

  it "applies a distant block as its date enters the client window" do
    distant = Time.zone.parse("2027-03-08 08:15")
    ConsultationBlock.create!(starts_at: distant.beginning_of_day, ends_at: distant.next_day.beginning_of_day)
    travel_to Time.zone.parse("2027-02-01 07:00")
    expect(settings.booking_dates).to cover(distant.to_date)
    expect(available).not_to include(distant)
  end

  it "adds exceptional Saturday appointments but gives blocks priority" do
    extra = ConsultationSlot.create!(starts_at: Time.zone.parse("2026-10-17 10:00"))
    expect(available).to include(extra.starts_at)
    ConsultationBlock.create!(starts_at: extra.starts_at, ends_at: extra.ends_at, all_day: false)
    expect(available).not_to include(extra.starts_at)
  end

  it "uses active local bookings and releases failed or canceled ones" do
    user = User.create!(email: "slot@example.com", password: "password123")
    booking = Booking.create!(user: user, package: create_package, name: "Marta", email: user.email, starts_at: monday)
    expect(booking.ends_at).to eq(monday + 90.minutes)
    expect(available).not_to include(monday)
    booking.update!(status: :confirmed)
    expect(available).not_to include(monday)
    booking.update!(status: :payment_failed)
    expect(available).to include(monday)
    booking.update!(status: :canceled)
    expect(available).to include(monday)
  end

  it "accounts for a consultation starting the previous day" do
    user = User.create!(email: "night@example.com", password: "password123")
    extra = ConsultationSlot.create!(starts_at: Time.zone.parse("2026-10-17 00:30"))
    Booking.create!(user: user, package: create_package, name: "Marta", email: user.email, starts_at: extra.starts_at - 1.hour)
    expect(available).not_to include(extra.starts_at)
  end

  it "keeps local wall-clock time when the UTC offset changes" do
    before_dst = available.find { |time| time.to_date == Date.new(2026, 10, 23) }
    after_dst = available.find { |time| time.to_date == Date.new(2026, 10, 26) }
    expect(before_dst.strftime("%H:%M")).to eq("08:15")
    expect(after_dst.strftime("%H:%M")).to eq("08:15")
    expect(before_dst.utc_offset - after_dst.utc_offset).to eq(1.hour)
  end

  it "omits nonexistent spring clock times rather than shifting the appointment" do
    settings.weekly_slots.destroy_all
    settings.weekly_slots.create!(weekday: 0, minute_of_day: 150)
    blocks = described_class.new(from: Date.new(2027, 3, 28), to: Date.new(2027, 3, 28), settings: settings).schedule_blocks
    expect(blocks).to be_empty
  end
end
