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
end
