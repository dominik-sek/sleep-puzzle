require 'rails_helper'

RSpec.describe "Admin::Bookings", type: :request do
  let(:package) { create_package(name: "Konsultacja") }
  let(:customer) { User.create!(email: "customer@example.com", password: "password123") }
  let(:admin) { User.create!(email: "owner@example.com", password: "password123", admin: true) }

  def create_booking(name:, status: :confirmed, starts_at: 1.day.from_now)
    Booking.create!(
      name: name,
      email: "#{name.parameterize}@example.com",
      starts_at: starts_at,
      status: status,
      package: package,
      user: customer
    )
  end

  it "redirects a non-admin away" do
    sign_in customer

    get admin_bookings_path

    expect(response).to redirect_to(root_path)
  end

  describe "pagination" do
    before { sign_in admin }

    it "shows only the first page and links to the second" do
      30.times { |i| create_booking(name: "Klient #{format('%02d', i)}", starts_at: i.days.from_now) }

      get admin_bookings_path

      # 30 bookings at the default limit of 25
      expect(response.body).to include("Klient 29")
      expect(response.body).not_to include("Klient 04")
      expect(response.body).to include("page=2")
    end

    it "shows the remainder on the second page" do
      30.times { |i| create_booking(name: "Klient #{format('%02d', i)}", starts_at: i.days.from_now) }

      get admin_bookings_path(page: 2)

      expect(response.body).to include("Klient 04")
      expect(response.body).not_to include("Klient 29")
    end

    it "renders the Polish info line" do
      30.times { |i| create_booking(name: "Klient #{format('%02d', i)}", starts_at: i.days.from_now) }

      get admin_bookings_path

      expect(response.body).to include("Wyświetlono")
      expect(response.body).to include(">1</span>–<span class=\"font-medium text-cream\">25</span>")
      expect(response.body).to include(">30</span>")
    end

    it "uses pagy's Polish aria labels rather than the component's English ones" do
      30.times { |i| create_booking(name: "Klient #{format('%02d', i)}", starts_at: i.days.from_now) }

      get admin_bookings_path

      expect(response.body).to include("Następna")
      expect(response.body).not_to include(%(aria-label="Next"))
    end

    it "still renders a single-page nav without page links" do
      create_booking(name: "Anna Kowalska")

      get admin_bookings_path

      expect(response.body).to include("Anna Kowalska")
      expect(response.body).not_to include("page=2")
    end
  end

  describe "GET /admin/bookings/:token" do
    it "shows a booking that belongs to someone else" do
      booking = create_booking(name: "Anna Kowalska")
      sign_in admin

      get admin_booking_path(booking)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Anna Kowalska", "customer@example.com")
    end

    it "links to the admin page, not the customer-scoped one, from the index" do
      booking = create_booking(name: "Anna Kowalska")
      sign_in admin

      get admin_bookings_path

      expect(response.body).to include(admin_booking_path(booking))
      expect(response.body).not_to include(%(href="#{booking_path(booking)}"))
    end

    # The link only renders once a calendar has been picked, so pin it rather than
    # depending on what the runner's database happens to hold.
    it "links out to the Google Calendar event" do
      allow(Integration).to receive(:google_calendar_id).and_return("abc123@group.calendar.google.com")
      booking = create_booking(name: "Anna Kowalska")
      booking.update!(calendar_event_id: "31dnutl6u8qj6prgerlnckm66s")
      sign_in admin

      get admin_booking_path(booking)

      expect(response.body).to include("https://www.google.com/calendar/event?eid=")
      expect(response.body).to include("Otwórz w Google Calendar")
    end

    it "says so when the booking holds no calendar event" do
      booking = create_booking(name: "Anna Kowalska")
      booking.update!(calendar_event_id: nil)
      sign_in admin

      get admin_booking_path(booking)

      expect(response.body).to include("nie jest zablokowany w kalendarzu")
      expect(response.body).not_to include("calendar/event?eid=")
    end

    it "404s on an unknown token" do
      sign_in admin

      get admin_booking_path(token: "nope")

      expect(response).to have_http_status(:not_found)
    end

    it "stays closed to non-admins" do
      booking = create_booking(name: "Anna Kowalska")
      sign_in customer

      get admin_booking_path(booking)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "filtering" do
    before { sign_in admin }

    it "narrows the list to the requested status" do
      create_booking(name: "Potwierdzona", status: :confirmed)
      create_booking(name: "Oczekujaca", status: :pending)

      get admin_bookings_path(status: "pending")

      expect(response.body).to include("Oczekujaca")
      expect(response.body).not_to include("Potwierdzona")
    end

    it "ignores an unknown status instead of raising" do
      create_booking(name: "Potwierdzona", status: :confirmed)

      get admin_bookings_path(status: "bogus")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Potwierdzona")
    end

    it "keeps the filter on page links" do
      30.times { |i| create_booking(name: "Klient #{format('%02d', i)}", status: :pending, starts_at: i.days.from_now) }

      get admin_bookings_path(status: "pending")

      expect(response.body).to include("status=pending&amp;page=2").or include("page=2&amp;status=pending")
    end
  end
end
