require "rails_helper"

# == Schema Information
#
# Table name: consultation_settings
#
#  id                    :bigint           not null, primary key
#  booking_window_months :integer          default(2), not null
#  local_availability    :boolean          default(FALSE), not null
#  minimum_notice_hours  :integer          default(24), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
RSpec.describe ConsultationSetting do
  include ActiveSupport::Testing::TimeHelpers
  let(:settings) { described_class.current }

  it "validates settings boundaries" do
    settings.assign_attributes(booking_window_months: 13, minimum_notice_hours: -1)
    expect(settings).not_to be_valid
    expect(settings.errors).to include(:booking_window_months, :minimum_notice_hours)
  end

  it "rejects overlapping weekly appointments, including across the week boundary" do
    settings.weekly_slots.build(weekday: 1, minute_of_day: 540)
    expect(settings).not_to be_valid
    settings.reload
    settings.weekly_slots.build(weekday: 6, minute_of_day: 23 * 60 + 45)
    settings.weekly_slots.build(weekday: 0, minute_of_day: 30)
    expect(settings).not_to be_valid
  end

  it "allows adjacent consultations" do
    settings.weekly_slots.build(weekday: 1, minute_of_day: 585)
    expect(settings).to be_valid
  end

  it "rejects appointments that overlap in elapsed time at the spring clock change" do
    settings.weekly_slots.build(weekday: 0, time_of_day: "01:30")
    settings.weekly_slots.build(weekday: 0, time_of_day: "03:00")
    expect(settings).not_to be_valid
    expect(settings.errors[:base].join).to include("zmiany czasu")
  end

  it "rejects malformed times" do
    settings.weekly_slots.build(weekday: 1, time_of_day: "25:70")
    expect(settings).not_to be_valid
  end

  it "rejects schedule changes overlapping an exceptional appointment" do
    date = Date.current.next_occurring(:saturday) + 1.week
    ConsultationSlot.create!(starts_at: Time.zone.parse("#{date} 10:00"))
    settings.weekly_slots.build(weekday: 6, minute_of_day: 600)
    expect(settings).not_to be_valid
    expect(settings.errors[:base].join).to include("dodatkowy termin")
  end
end
