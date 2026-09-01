require 'rails_helper'

RSpec.describe Integration do
  describe ".google_calendar_id" do
    it "returns the calendar picked in the panel" do
      Integration.create!(service_name: Integration::GOOGLE_CALENDAR, calendar_id: "picked@group.calendar.google.com")

      expect(Integration.google_calendar_id).to eq("picked@group.calendar.google.com")
    end

    # The pre-panel setup, kept working so a deploy that has not chosen a
    # calendar yet still writes bookings somewhere.
    it "falls back to GOOGLE_CALENDAR_ID when nothing has been picked" do
      stub_const("ENV", ENV.to_h.merge("GOOGLE_CALENDAR_ID" => "env@group.calendar.google.com"))
      Integration.create!(service_name: Integration::GOOGLE_CALENDAR)

      expect(Integration.google_calendar_id).to eq("env@group.calendar.google.com")
    end

    it "prefers the picked calendar over the env var" do
      stub_const("ENV", ENV.to_h.merge("GOOGLE_CALENDAR_ID" => "env@group.calendar.google.com"))
      Integration.create!(service_name: Integration::GOOGLE_CALENDAR, calendar_id: "picked@group.calendar.google.com")

      expect(Integration.google_calendar_id).to eq("picked@group.calendar.google.com")
    end

    it "is nil when there is neither" do
      stub_const("ENV", ENV.to_h.except("GOOGLE_CALENDAR_ID"))

      expect(Integration.google_calendar_id).to be_nil
    end
  end
end
