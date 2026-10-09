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

    it "opens the refund policy outside the booking frame" do
      get bookings_path
      link = Nokogiri::HTML(response.body).at_css("turbo-frame#booking_form a[href='/refunds']")
      expect(link["data-turbo-frame"]).to eq("_top")
    end

    it "restores a selected available slot after sign-in" do
      date = Date.current.next_occurring(:monday).iso8601
      hour = ConsultationSetting.current.weekly_slots.where(weekday: Date.iso8601(date).wday).order(:minute_of_day).first.time_of_day

      get bookings_path(date: date, hour: hour)

      expect(response.body).to include(%(data-cally-selected-date-value="#{date}"))
      expect(response.body).to include(%(data-cally-selected-hour-value="#{hour}"))
    end

    it "does not restore a slot that is not available" do
      get bookings_path(date: 1.week.from_now.to_date.iso8601, hour: "23:59")

      expect(response.body).to include('data-cally-selected-date-value=""')
      expect(response.body).to include('data-cally-selected-hour-value=""')
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
      expect(response.body).to include("https://www.instagram.com/sleep.puzzle/")
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
                   date: Date.current.next_occurring(:monday).to_s, hour: "08:15",
                   early_service_consent: "1", policy_token: RefundPolicySnapshot.token(:booking) } }
    end

    it "asks for a new slot when a malformed date is submitted" do
      params = booking_params
      params[:booking][:date] = "2026-99-99"

      expect { post bookings_path, params: params }.not_to change(Booking, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("bookings.form.reselect_slot"))
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

      expect { post bookings_path, params: booking_params, as: :turbo_stream }.to change(Booking, :count).by(1)

      expect(Booking.last).to be_pending
      expect(response.body).to include('target="availability"', 'target="paddle_checkout"')
    end

    it "requires early-service consent for a slot within the first 14 days" do
      params = booking_params
      params[:booking].delete(:early_service_consent)
      expect { post bookings_path, params: params }.not_to change(Booking, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("refunds.booking_consent_error"))
    end

    it "allows a later appointment without inventing consent" do
      allow_any_instance_of(BookingsController).to receive(:checkout_for).and_return({ items: [] })
      params = booking_params
      params[:booking][:date] = (Date.current + 21.days).next_occurring(:monday).to_s
      params[:booking].delete(:early_service_consent)
      expect { post bookings_path, params: params, as: :turbo_stream }.to change(Booking, :count).by(1)
      expect(Booking.last.consent_accepted_at).to be_nil
      expect(Booking.last.legal_snapshot["kind"]).to eq("booking")
    end

    it "rejects a forged policy token even for a later appointment" do
      params = booking_params
      params[:booking][:date] = (Date.current + 21.days).next_occurring(:monday).to_s
      params[:booking][:policy_token] = "forged"
      expect { post bookings_path, params: params }.not_to change(Booking, :count)
      expect(response.body).to include(I18n.t("refunds.policy_expired"))
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

    it "retains an unknown payment without a false payment or release message" do
      allow(BookingPaymentCheckService).to receive(:call).and_return(check(declined: true, unpaid: false))
      delete abandon_booking_path(booking), as: :turbo_stream
      expect(booking.reload).to be_pending
      expect(response.body).to include("Nie mamy jeszcze potwierdzenia statusu płatności")
      expect(response.body).not_to include("Płatność została zaksięgowana", "Termin nie został zarezerwowany")
    end

    it "retains the calendar event for retry while releasing the local slot after a Google outage" do
      allow(BookingPaymentCheckService).to receive(:call).and_return(check)
      booking.update!(calendar_event_id: "google_pending")
      allow(BookingCalendarService).to receive(:call).and_call_original
      allow(GoogleCalendarService).to receive(:call).and_raise(GoogleCalendarService::NotConnected)
      expect { delete abandon_booking_path(booking), as: :turbo_stream }.to have_enqueued_job(SyncBookingCalendarJob).with(booking.id)
      expect(booking.reload).to be_canceled
      expect(booking.calendar_event_id).to eq("google_pending")
      expect(booking).to be_calendar_sync_pending
      expect(response.body).to include("termin jest znów dostępny")
    end
  end

  it "does not show an unused refund status after successful payment" do
    sign_in user
    booking = user.bookings.create!(package: create_package, name: "Marta", email: user.email, starts_at: 1.month.from_now,
      status: :confirmed, confirmed_at: Time.current, paddle_transaction_id: "txn_confirmed")
    get booking_path(booking)
    expect(response.body).not_to include("Stan zwrotu", "Brak zwrotu")
  end
end
