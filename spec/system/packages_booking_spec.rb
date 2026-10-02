require "rails_helper"

RSpec.describe "Booking from packages", type: :system do
  include Warden::Test::Helpers

  before do
    allow(GoogleCalendarService).to receive(:call).and_return(instance_double(GoogleCalendarService, busy: []))
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price ])
    create_package(name: "Szybka ulga")
  end

  after { Warden.test_reset! }

  def select_first_available_slot
    panel = first('[data-cally-target="hoursPanel"]:has(button:not(:disabled))', visible: :all)
    date = panel[:"data-date"]
    page.execute_script(<<~JS, date)
      const calendar = document.querySelector("calendar-date")
      calendar.value = arguments[0]
      calendar.dispatchEvent(new Event("change", { bubbles: true }))
    JS
    within('[data-cally-target="hoursPanel"]:not([hidden])') do
      find('button:not(:disabled)', match: :first).click
    end
    date
  end

  it "takes a signed-in customer to booking with the chosen package" do
    user = User.create!(email: "customer@example.com", password: "password123")
    login_as user, scope: :user

    visit packages_path
    expect(page).not_to have_css("#calendar")
    find('a[aria-label="Zobacz terminy - Szybka ulga"]').click

    expect(page).to have_current_path(bookings_path(package_id: Package.last.id))
    expect(page).to have_select("booking_package_id", selected: "Szybka ulga", visible: :all)
  end

  it "restores the selected slot after a visitor signs in" do
    user = User.create!(email: "customer@example.com", password: "password123")
    visit packages_path
    date = select_first_available_slot

    link = find_link(I18n.t("offers.continue_booking"))
    expect(URI.parse(link[:href]).query).to include("date=#{date}", "hour=08%3A15")
    link.click

    expect(page).to have_current_path(new_user_session_path)
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "password123"
    click_button I18n.t("auth.sign_in.submit")

    expect(page).to have_current_path(bookings_path(date: date, hour: "08:15"))
    expect(find('input[name="booking[date]"]', visible: :all).value).to eq(date)
    expect(find('input[name="booking[hour]"]', visible: :all).value).to eq("08:15")
    expect(page).to have_button(I18n.t("bookings.form.submit"))
  end
end
