require 'rails_helper'

RSpec.describe GoogleCalendarService do
  let(:authorizer) { instance_double(Google::Auth::WebUserAuthorizer) }

  before { allow(AuthorizeCalendarService).to receive(:call).and_return(authorizer) }

  describe "when there is no usable calendar" do
    # Nothing in the token store, because nobody has been through the OAuth flow
    # in the panel yet. This used to hand back a service with a nil authorization,
    # which looked fine until the first API call answered 401.
    it "refuses to build a service when nothing is connected" do
      allow(authorizer).to receive(:get_credentials).and_return(nil)

      expect { described_class.call }
        .to raise_error(described_class::NotConnected, /no Google Calendar is connected/)
    end

    # A refresh token Google has since dropped: it answers 400 "Token has been
    # expired or revoked" as soon as the gem tries to mint an access token from
    # it, which surfaced as a Signet error nothing up the stack was catching.
    it "reports a dead stored grant as not connected" do
      allow(authorizer).to receive(:get_credentials)
        .and_raise(Signet::AuthorizationError.new("Token has been expired or revoked"))

      expect { described_class.call }
        .to raise_error(described_class::NotConnected, /no longer valid/)
    end

    # the distinction the class exists to draw - callers treat a missing
    # connection differently from a call that happened to fail
    it "is not mistaken for a Google::Apis::Error" do
      expect(described_class::NotConnected.new).not_to be_a(Google::Apis::Error)
    end
  end

  describe "when no calendar has been picked" do
    before do
      stub_const("ENV", ENV.to_h.except("GOOGLE_CALENDAR_ID"))
      allow(authorizer).to receive(:get_credentials)
        .and_return(instance_double(Google::Auth::UserRefreshCredentials))
    end

    # Connecting the account and picking a calendar are two separate steps, and
    # calling Google with a nil id only yields a confusing 404.
    it "refuses to act on a connection with no calendar" do
      expect { described_class.call.busy }
        .to raise_error(described_class::NoCalendarSelected, /no calendar has been selected/)
    end

    # Callers only rescue NotConnected, and half-finished setup has to land there
    # too rather than blow up a booking.
    it "is a kind of NotConnected" do
      expect(described_class::NoCalendarSelected.new).to be_a(described_class::NotConnected)
    end
  end

  it "builds a service when the grant works" do
    allow(authorizer).to receive(:get_credentials)
      .and_return(instance_double(Google::Auth::UserRefreshCredentials))

    expect(described_class.call).to be_a(described_class)
  end

  describe "#busy" do
    let(:api) { instance_double(Google::Apis::CalendarV3::CalendarService, :authorization= => nil) }

    before do
      allow(authorizer).to receive(:get_credentials)
        .and_return(instance_double(Google::Auth::UserRefreshCredentials))
      allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(api)
      allow(Integration).to receive(:google_calendar_id).and_return("cal@example.com")
    end

    def returns(*items, then_page: nil)
      pages = [ page(items, next_page_token: then_page ? "next" : nil), then_page ].compact
      allow(api).to receive(:list_events).and_return(*pages)
    end

    def page(items, next_page_token: nil)
      instance_double(Google::Apis::CalendarV3::Events, items: items, next_page_token: next_page_token)
    end

    def all_day(from, to, transparency: "transparent")
      Google::Apis::CalendarV3::Event.new(
        transparency: transparency,
        start: Google::Apis::CalendarV3::EventDateTime.new(date: Date.parse(from)),
        end: Google::Apis::CalendarV3::EventDateTime.new(date: Date.parse(to))
      )
    end

    def timed(from, to)
      Google::Apis::CalendarV3::Event.new(
        start: Google::Apis::CalendarV3::EventDateTime.new(date_time: Time.zone.parse(from)),
        end: Google::Apis::CalendarV3::EventDateTime.new(date_time: Time.zone.parse(to))
      )
    end

    # The bug this replaced freebusy over: Google Calendar marks all-day events
    # "free" by default, freebusy drops those, and a week of leave blocked nothing.
    it "blocks an all-day event Google calls free" do
      returns(all_day("2026-09-11", "2026-09-12"))

      expect(described_class.call.busy).to eq([
        Time.zone.parse("2026-09-11 00:00")...Time.zone.parse("2026-09-12 00:00")
      ])
    end

    # Google's all-day end date is exclusive: the 11th to the 12th is one day.
    it "does not stretch an all-day event a day past its end" do
      returns(all_day("2026-09-11", "2026-09-12"))
      period = described_class.call.busy.first

      expect(period.end).to eq(Time.zone.parse("2026-09-12 00:00"))
      expect(period).not_to cover(Time.zone.parse("2026-09-12 08:15"))
    end

    it "blocks a timed event" do
      returns(timed("2026-09-11 08:15", "2026-09-11 09:45"))

      expect(described_class.call.busy).to eq([
        Time.zone.parse("2026-09-11 08:15")...Time.zone.parse("2026-09-11 09:45")
      ])
    end

    it "expands recurring events rather than reading them as one row" do
      returns(timed("2026-09-11 08:15", "2026-09-11 09:45"))

      described_class.call.busy

      expect(api).to have_received(:list_events).with("cal@example.com", hash_including(single_events: true))
    end

    # A dropped page reads as free time, which is the expensive direction to be
    # wrong in.
    it "follows pagination" do
      returns(timed("2026-09-11 08:15", "2026-09-11 09:45"),
              then_page: page([ timed("2026-09-18 08:15", "2026-09-18 09:45") ]))

      expect(described_class.call.busy.size).to eq(2)
    end

    it "ignores an event carrying neither a date nor a time" do
      returns(Google::Apis::CalendarV3::Event.new)

      expect(described_class.call.busy).to be_empty
    end
  end
end
