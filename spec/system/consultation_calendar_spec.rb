require "rails_helper"

RSpec.describe "Managing consultation availability", type: :system do
  include Warden::Test::Helpers
  include ActiveSupport::Testing::TimeHelpers

  before do
    travel_to Time.zone.parse("2026-10-05 07:00")
    @admin = User.create!(email: "calendar-owner@example.com", password: "password123", admin: true)
    @customer = User.create!(email: "calendar-customer@example.com", password: "password123")
    create_package(name: "Konsultacja", name_en: "Consultation")
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price ])
    allow(GoogleCalendarService).to receive(:call).and_raise(GoogleCalendarService::NotConnected)
    login_as @admin, scope: :user
  end

  after do
    Warden.test_reset!
    travel_back
  end

  it "edits the schedule, blocks a day, adds an exceptional appointment and publishes it in PL and EN" do
    visit edit_admin_consultation_settings_path
    within(find("fieldset", text: I18n.t("date.day_names")[1])) do
      fill_in "Godzina", with: "10:00"
      fill_in "Dodaj godzinę", with: "12:00"
    end
    fill_in "Okno rezerwacji (miesiące)", with: "4"
    click_button "Zapisz harmonogram"
    expect(page).to have_current_path(admin_consultation_calendar_path)
    expect(ConsultationSetting.current.weekly_slots.where(weekday: 1).map(&:time_of_day)).to contain_exactly("10:00", "12:00")

    visit new_admin_consultation_block_path(date: "2026-10-12")
    fill_in "Notatka (tylko dla admina)", with: "Prywatny urlop"
    click_button "Zapisz blokadę"
    expect(page).to have_content("Prywatny urlop")

    visit new_admin_consultation_slot_path(date: "2026-10-17")
    fill_in "Godzina rozpoczęcia (Warszawa)", with: "11:00"
    click_button "Zapisz termin"
    expect(page).to have_content("Dodatkowe terminy")

    visit edit_admin_consultation_settings_path
    check "Przeniosłam/przeniosłem wszystkie potrzebne blokady z Google."
    accept_confirm { click_button "Przejdź na dostępność z aplikacji" }
    expect(page).to have_current_path(admin_consultation_calendar_path)
    expect(page).not_to have_content("Trwa przenoszenie kalendarza")
    visit admin_consultation_calendar_path(date: "2026-10-17")
    page.driver.browser.manage.window.resize_to(1440, 1000)
    page.save_screenshot(Rails.root.join("tmp", "consultation-calendar-desktop.png"))
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be true
    page.save_screenshot(Rails.root.join("tmp", "consultation-calendar-mobile.png"))

    logout(:user)
    login_as @customer, scope: :user
    [ nil, "en" ].each do |locale|
      visit bookings_path(locale: locale)
      expect(page).not_to have_content("Prywatny urlop")
      blocked = find('[data-date="2026-10-12"]', visible: :all)
      expect(blocked).to have_css('button[disabled]', count: 2, visible: :all)
      extra = find('[data-date="2026-10-17"]', visible: :all)
      expect(extra).to have_css('button:not([disabled])[data-hour="11:00"]', visible: :all)
      expect(find('[data-cally-to-value]', visible: :all)['data-cally-to-value']).to eq("2027-02-05")
      expect(page).not_to have_content(I18n.t("bookings.calendar.unavailable", locale: locale || :pl))
    end
  end
end
