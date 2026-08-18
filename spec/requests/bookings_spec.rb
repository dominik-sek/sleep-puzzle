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
end
