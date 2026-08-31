require 'rails_helper'

RSpec.describe "Bookings", type: :request do
  let(:user) { User.create!(email: "customer@example.com", password: "password123") }

  # the booking form lives on the index, and loading it reaches Google Calendar
  before do
    allow(GoogleCalendarService).to receive(:call).and_return(instance_double(GoogleCalendarService, busy: []))
  end

  describe "GET /bookings" do
    before { sign_in user }

    # arrived from a package card's "Umów konsultację"
    it "preselects the package passed in the query string" do
      package = create_package(name: "Szybka ulga")

      get bookings_path(package_id: package.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(selected="selected" value="#{package.id}">Szybka ulga))
    end

    it "ignores an unpublished package rather than offering it" do
      package = create_package(name: "Szkic", published: false)

      get bookings_path(package_id: package.id)

      expect(response.body).not_to include(%(selected="selected" value="#{package.id}">))
    end

    it "ignores an unknown package id" do
      get bookings_path(package_id: 999_999)

      expect(response).to have_http_status(:ok)
    end
  end

  # The owner has not connected her calendar yet, or the grant she gave has since
  # been revoked. Reading availability used to raise straight out of the action.
  describe "GET /bookings with no usable calendar" do
    before do
      sign_in user
      allow(GoogleCalendarService).to receive(:call)
        .and_raise(GoogleCalendarService::NotConnected, "no Google Calendar is connected")
    end

    it "still renders the page" do
      get bookings_path

      expect(response).to have_http_status(:ok)
    end

    it "says why instead of looking fully booked" do
      get bookings_path

      expect(response.body).to include(I18n.t("bookings.calendar.unavailable"))
    end

    # escaped, because the English copy has an apostrophe in it and the page does
    # not
    it "says it in English on the English site" do
      get bookings_path(locale: :en)

      expect(response.body).to include(CGI.escapeHTML(I18n.t("bookings.calendar.unavailable", locale: :en)))
    end

    # The safe direction: with nothing to check against, a slot offered as free is
    # a guess, and a wrong guess double-books the owner.
    it "offers no dates at all" do
      get bookings_path

      expect(response.body).to include(%(data-cally-available-dates-value="[]"))
    end

    # a calendar that is reachable but erroring is the same story for the buyer
    it "degrades the same way when Google itself errors" do
      allow(GoogleCalendarService).to receive(:call)
        .and_raise(Google::Apis::ServerError.new("backend error"))

      get bookings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("bookings.calendar.unavailable"))
    end
  end

  # POST /bookings had no coverage at all, which is how the write-before-you-can-
  # charge ordering survived. These lock the money path.
  # distinct from "we could not read the calendar": here it was read fine and she
  # is simply booked out. That used to render a dead grid with no explanation.
  describe "GET /bookings with a readable but fully-booked calendar" do
    before do
      sign_in user
      allow(SlotComparatorService).to receive(:call).and_return([])
    end

    it "says she is booked out rather than showing an unusable grid" do
      get bookings_path

      expect(response.body).to include("nie ma wolnych terminów")
      expect(response.body).to include(contact_path)
    end

    it "does not claim the calendar is unreadable" do
      get bookings_path

      expect(response.body).not_to include(I18n.t("bookings.calendar.unavailable"))
    end
  end

  describe "POST /bookings" do
    before do
      sign_in user
      allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_123") ])
      allow(BookingCalendarService).to receive(:call).and_return(
        instance_double(BookingCalendarService, create: true, release: true)
      )
    end

    let(:package) { create_package(name: "Szybka ulga", paddle_price_id: "pri_123") }

    def booking_params(pkg = package)
      { booking: { name: "Marta", email: user.email, package_id: pkg.id,
                   date: 1.week.from_now.to_date.to_s, hour: "08:15" } }
    end

    it "refuses a package Paddle cannot price, before writing anything" do
      unpriceable = create_package(name: "Bez ceny", paddle_price_id: "pri_gone")

      expect { post bookings_path, params: booking_params(unpriceable) }
        .not_to change(Booking, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Tego pakietu nie da się teraz opłacić")
    end

    # the slot must not leave the public calendar until there is something to pay with
    it "does not hold the calendar slot when the checkout cannot be prepared" do
      allow_any_instance_of(BookingsController).to receive(:checkout_for).and_return(nil)
      calendar = instance_double(BookingCalendarService, create: true, release: true)
      allow(BookingCalendarService).to receive(:call).and_return(calendar)

      expect { post bookings_path, params: booking_params }.not_to change(Booking, :count)

      expect(calendar).not_to have_received(:create)
    end

    it "holds the slot and opens checkout when Paddle is reachable" do
      allow_any_instance_of(BookingsController)
        .to receive(:checkout_for).and_return({ items: [] })

      expect { post bookings_path, params: booking_params }.to change(Booking, :count).by(1)

      expect(Booking.last).to be_pending
    end
  end

  # abandon had no coverage at all, and it is the path a declined card takes.
  describe "DELETE /bookings/:token/abandon" do
    before do
      sign_in user
      allow(BookingCalendarService).to receive(:call).and_return(
        instance_double(BookingCalendarService, create: true, release: true)
      )
    end

    let(:package) { create_package(name: "Szybka ulga", paddle_price_id: "pri_123") }
    let(:booking) do
      Booking.create!(user: user, package: package, name: "Marta", email: user.email,
                      starts_at: 1.week.from_now, status: :pending)
    end

    def check(paid: false, declined: false, unpaid: true)
      instance_double(BookingPaymentCheckService, paid?: paid, declined?: declined, unpaid?: unpaid)
    end

    it "releases the slot and says nothing was charged" do
      allow(BookingPaymentCheckService).to receive(:call).and_return(check)

      delete abandon_booking_path(booking), as: :turbo_stream

      expect(Booking.exists?(booking.id)).to be(false)
      expect(response.body).to include("Nie pobraliśmy żadnej opłaty")
    end

    # the verdict has to survive on the page, not evaporate with a toast
    it "keeps the verdict in the page rather than only in a toast" do
      allow(BookingPaymentCheckService).to receive(:call).and_return(check)

      delete abandon_booking_path(booking), as: :turbo_stream

      expect(response.body).to include('target="booking_notice"')
    end

    # checkout.closed also fires after a successful payment
    it "does not delete a booking Paddle has already taken money for" do
      allow(BookingPaymentCheckService).to receive(:call)
        .and_return(check(paid: true, unpaid: false))

      delete abandon_booking_path(booking), as: :turbo_stream

      expect(Booking.exists?(booking.id)).to be(true)
    end
  end
end
