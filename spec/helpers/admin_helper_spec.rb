require 'rails_helper'

RSpec.describe AdminHelper, type: :helper do
  describe "#google_calendar_event_url" do
    around do |example|
      original = ENV["GOOGLE_CALENDAR_ID"]
      ENV["GOOGLE_CALENDAR_ID"] = "abc123@group.calendar.google.com"
      example.run
      ENV["GOOGLE_CALENDAR_ID"] = original
    end

    # Pins the encoding to what Google puts in an event's htmlLink: base64 of
    # "<event id> <calendar id>" with the domain cut to its first character.
    # Encoding the full domain yields a different eid than Google's own link.
    it "reproduces Google's eid encoding" do
      booking = Booking.new(calendar_event_id: "31dnutl6u8qj6prgerlnckm66s")

      url = helper.google_calendar_event_url(booking)
      eid = Rack::Utils.parse_query(URI(url).query)["eid"]

      expect(url).to start_with("https://www.google.com/calendar/event?eid=")
      expect(Base64.decode64(eid)).to eq("31dnutl6u8qj6prgerlnckm66s abc123@g")
      expect(eid).not_to include("=")
    end

    it "returns nil when the booking holds no calendar event" do
      expect(helper.google_calendar_event_url(Booking.new(calendar_event_id: nil))).to be_nil
    end

    it "returns nil when no calendar is configured" do
      ENV["GOOGLE_CALENDAR_ID"] = nil

      expect(helper.google_calendar_event_url(Booking.new(calendar_event_id: "abc"))).to be_nil
    end
  end
end
