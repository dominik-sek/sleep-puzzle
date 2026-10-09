require "rails_helper"

RSpec.describe "Local consultation availability", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  let(:user) { User.create!(email: "local@example.com", password: "password123") }
  let(:package) { create_package(paddle_price_id: "pri_123") }

  before do
    travel_to Time.zone.parse("2026-10-05 07:00")
    ConsultationSetting.current.update!(local_availability: true)
    sign_in user
    allow(GoogleCalendarService).to receive(:call).and_raise(GoogleCalendarService::NotConnected)
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_123") ])
    allow_any_instance_of(BookingsController).to receive(:checkout_for).and_return({ items: [] })
  end
  after { travel_back }

  def reserve(date: "2026-10-12", hour: "08:15")
    post bookings_path, params: { booking: { name: "Marta", package_id: package.id, date: date, hour: hour,
      early_service_consent: "1", policy_token: RefundPolicySnapshot.token(:booking) } }, as: :turbo_stream
  end

  it "works in PL and EN without making a Google availability request" do
    %w[pl en].each do |locale|
      get bookings_path(locale: locale == "pl" ? nil : locale)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(CGI.escapeHTML(I18n.t("bookings.calendar.unavailable", locale: locale)))
      expect(response.body).to include("2026-10-12")
    end
    expect(GoogleCalendarService).not_to have_received(:call)
  end

  it "reserves locally even when writing the Google copy fails and prevents a second reservation" do
    expect { reserve }.to change(Booking, :count).by(1)
    expect(Booking.last).to be_pending
    expect(Booking.last.calendar_event_id).to be_nil
    expect { reserve }.not_to change(Booking, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include(I18n.t("bookings.form.reselect_slot"))
  end

  it "rejects dates outside the window, past times, unavailable hours and notice violations before checkout" do
    allow_any_instance_of(BookingsController).to receive(:checkout_for).and_raise("Checkout should not run")
    [ { date: "2027-03-08" }, { date: "2026-10-05" }, { hour: "09:00" }, { date: "2026-09-28" }, { date: "2026-10-12T08:15:00Z" }, { hour: "08:15:00" } ].each do |values|
      expect { reserve(**values) }.not_to change(Booking, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  it "rejects a blocked appointment and keeps private reasons out of public markup" do
    ConsultationBlock.create!(starts_at: Time.zone.parse("2026-10-12 09:00"), ends_at: Time.zone.parse("2026-10-12 10:00"), all_day: false, note: "Poufna notatka")
    expect { reserve }.not_to change(Booking, :count)
    get bookings_path
    expect(response.body).not_to include("Poufna notatka")
  end

  it "uses the configured window in frontend boundaries" do
    ConsultationSetting.current.update!(booking_window_months: 4)
    get bookings_path
    expect(response.body).to include('data-cally-to-value="2027-02-05"')
  end
end
