require 'rails_helper'

RSpec.describe AdminHelper, type: :helper do
  describe "#admin_sidebar_items" do
    it "offers the Google Calendar screen" do
      item = helper.admin_sidebar_items.find { |i| i[:href] == integrations_google_calendar_path }

      expect(item).to be_present
      expect(item[:label]).to eq("Kalendarz")
    end

    # It is the one nav entry pointing outside the Admin:: namespace, so the
    # active rule cannot key off an `admin_` controller name like the others.
    it "marks the calendar item active on its own screen" do
      allow(helper).to receive(:controller_name).and_return("google_calendar")

      active = helper.admin_sidebar_items.select { |i| i[:active] }

      expect(active.map { |i| i[:label] }).to eq([ "Kalendarz" ])
    end

    it "leaves it inactive elsewhere" do
      allow(helper).to receive(:controller_name).and_return("bookings")

      active = helper.admin_sidebar_items.select { |i| i[:active] }

      expect(active.map { |i| i[:label] }).to eq([ "Rezerwacje" ])
    end

    # Both mounted engines render in their own layout, so once you are on either
    # screen the panel's sidebar is gone. The nav entry is the only way in.
    it "offers the two mounted dashboards" do
      hrefs = helper.admin_sidebar_items.map { |i| i[:href] }

      expect(hrefs).to include(admin_mission_control_jobs_path, admin_pg_hero_path)
    end

    it "points every item at an icon that exists" do
      expect { helper.admin_sidebar_items.each { |i| helper.icon(i[:icon]) } }.not_to raise_error
    end
  end

  describe "#google_calendar_event_url" do
    before do
      allow(Integration).to receive(:google_calendar_id).and_return("abc123@group.calendar.google.com")
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
      allow(Integration).to receive(:google_calendar_id).and_return(nil)

      expect(helper.google_calendar_event_url(Booking.new(calendar_event_id: "abc"))).to be_nil
    end
  end
end
