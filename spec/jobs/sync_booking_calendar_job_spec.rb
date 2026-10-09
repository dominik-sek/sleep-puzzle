require "rails_helper"

RSpec.describe SyncBookingCalendarJob do
  let(:user) { User.create!(email: "calendar@example.com", password: "password123") }
  let(:booking) { user.bookings.create!(name: "Marta", email: user.email, package: create_package,
    starts_at: 3.days.from_now, status: :confirmed, calendar_event_id: "google_event", calendar_sync_pending: true) }
  let(:google) { instance_double(GoogleCalendarService) }

  before { allow(GoogleCalendarService).to receive(:call).and_return(google) }

  it "patches the existing event's time rather than leaving a duplicate" do
    expect(google).to receive(:patch_event).with(hash_including(event_id: "google_event", start: instance_of(Google::Apis::CalendarV3::EventDateTime), end: instance_of(Google::Apis::CalendarV3::EventDateTime)))
    described_class.perform_now(booking.id)
    expect(booking.reload.calendar_sync_pending).to be(false)
  end

  it "retries a Google failure without reverting local cancellation" do
    booking.update!(status: :canceled, canceled_at: Time.current)
    allow(google).to receive(:delete_event).and_raise(Google::Apis::ServerError, "unavailable")
    expect { described_class.perform_now(booking.id) }.to have_enqueued_job(described_class).with(booking.id)
    expect(booking.reload).to be_canceled
    expect(booking.calendar_sync_pending).to be(true)
    expect(booking.calendar_event_id).to eq("google_event")
  end

  it "treats an already-deleted event as successful cancellation" do
    booking.update!(status: :canceled, canceled_at: Time.current)
    allow(google).to receive(:delete_event).and_raise(Google::Apis::ClientError, "notFound")
    described_class.perform_now(booking.id)
    expect(booking.reload.calendar_event_id).to be_nil
    expect(booking.calendar_sync_pending).to be(false)
  end

  it "uses the latest booking state when an older reschedule job runs after cancellation" do
    booking.update!(status: :canceled, canceled_at: Time.current)
    expect(google).to receive(:delete_event).with(event_id: "google_event")
    expect(google).not_to receive(:patch_event)
    described_class.perform_now(booking.id)
  end
end
