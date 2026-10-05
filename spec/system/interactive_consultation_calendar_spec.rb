require "rails_helper"

RSpec.describe "Interactive consultation calendar", type: :system do
  include Warden::Test::Helpers
  include ActiveSupport::Testing::TimeHelpers

  before do
    travel_to Time.zone.parse("2026-10-05 07:00")
    @admin = User.create!(email: "interactive-calendar@example.com", password: "password123", admin: true)
    ConsultationSetting.current.update!(local_availability: true)
    allow(GoogleCalendarService).to receive(:call).and_raise(GoogleCalendarService::NotConnected)
    login_as @admin, scope: :user
    page.driver.browser.manage.window.resize_to(1440, 1000)
    visit admin_consultation_calendar_path
  end

  after do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") if @phone
    Warden.test_reset!
    travel_back
  end

  def day(date)
    find("button[data-date='#{date}']")
  end

  def dialog
    find("dialog[open]")
  end

  it "opens day actions by keyboard, creates a block in the dialog and restores focus after Escape" do
    day("2026-10-12").send_keys(:enter)
    within(dialog) do
      expect(page).to have_content("12 października 2026")
      box = page.evaluate_script("document.querySelector('dialog').getBoundingClientRect().toJSON()")
      expect(box["left"] + box["width"] / 2).to be_within(1).of(720)
      expect(box["top"] + box["height"] / 2).to be_within(1).of(page.evaluate_script("window.innerHeight / 2"))
      page.save_screenshot(Rails.root.join("tmp", "interactive-consultation-desktop.png"))
      click_link "Zablokuj dzień lub godziny"
      expect(page).to have_link("Szczegóły dnia")
      fill_in "Notatka (tylko dla admina)", with: "Wolny dzień"
      click_button "Zapisz blokadę"
    end
    expect(page).not_to have_css("dialog[open]")
    expect(page).to have_content("Zapisano blokadę")
    expect(ConsultationBlock.last.note).to eq("Wolny dzień")
    day("2026-10-12").click
    expect(dialog).to have_content("Wolny dzień")
    dialog.send_keys(:escape)
    expect(page).not_to have_css("dialog[open]")
    expect(page.evaluate_script("document.activeElement.dataset.date")).to eq("2026-10-12")
  end

  it "preserves arbitrary selection and Shift ranges across months and resets when leaving" do
    click_button "Zaznacz dni"
    day("2026-10-30").click
    click_link "Następny miesiąc →"
    expect(page).to have_css('#consultation_calendar_month [data-month-date="2026-11-01"]')
    day("2026-11-02").click(:shift)
    expect(page).to have_content("Zaznaczone dni: 4")
    click_link "← Poprzedni miesiąc"
    expect(day("2026-10-30")["aria-pressed"]).to eq("true")
    expect(day("2026-10-31")["aria-pressed"]).to eq("true")
    day("2026-10-12").click
    expect(page).to have_content("Zaznaczone dni: 5")
    click_button "Wyczyść"
    expect(page).to have_content("Zaznaczone dni: 0")
    expect(page).to have_button("Zablokuj zaznaczone", disabled: true)
    day("2026-10-12").click
    click_link "Harmonogram i ustawienia"
    visit admin_consultation_calendar_path
    expect(page).to have_button("Zaznacz dni", exact: true)
    expect(day("2026-10-12")["aria-pressed"]).to eq("false")
  end

  it "resizes Shift ranges around a stable anchor and supports deselecting ranges" do
    click_button "Zaznacz dni"
    day("2026-10-07").click
    day("2026-10-12").click
    day("2026-10-16").click(:shift)
    expect(page).to have_content("Zaznaczone dni: 6")
    day("2026-10-14").click(:shift)
    expect(page).to have_content("Zaznaczone dni: 4")
    expect(day("2026-10-16")["aria-pressed"]).to eq("false")
    day("2026-10-10").click(:shift)
    expect(page).to have_content("Zaznaczone dni: 4")
    expect(day("2026-10-14")["aria-pressed"]).to eq("false")
    expect(day("2026-10-07")["aria-pressed"]).to eq("true")
    day("2026-10-10").click
    day("2026-10-12").click(:shift)
    expect(page).to have_content("Zaznaczone dni: 1")
    expect(day("2026-10-12")["aria-pressed"]).to eq("false")
  end

  it "supports date navigation, all-day controls, back, close and reopening the same day" do
    fill_in "Przejdź do daty", with: Date.new(2026, 11, 17)
    click_button "Pokaż"
    expect(page).to have_css('#consultation_calendar_month [data-month-date="2026-11-01"]')
    day("2026-11-17").click
    within(dialog) do
      click_link "Zablokuj dzień lub godziny"
      expect(page).to have_field("Godzina początku", disabled: true)
      uncheck "Całe dni"
      expect(page).to have_field("Godzina początku", disabled: false)
      check "Całe dni"
      expect(page).to have_field("Godzina końca", disabled: true)
      click_link "Szczegóły dnia"
      expect(page).to have_content("17 listopada 2026")
      click_button "Zamknij"
    end
    expect(page).not_to have_css("dialog[open]")
    day("2026-11-17").click
    expect(dialog).to have_content("17 listopada 2026")
    within(dialog) { click_link "Dodaj termin" }
    within(dialog) do
      fill_in "Godzina rozpoczęcia (Warszawa)", with: Time.zone.parse("2026-11-17 16:00")
      click_button "Zapisz termin"
    end
    expect(page).not_to have_css("dialog[open]")
    day("2026-11-17").click
    expect(dialog).to have_content("Dodatkowy termin 16:00")
  end

  it "persists nonadjacent bulk blocks and updates public availability without leaving the calendar" do
    click_button "Zaznacz dni"
    day("2026-10-12").click
    day("2026-10-14").click
    click_button "Zablokuj zaznaczone"
    within(dialog) do
      expect(page).to have_content("Wybrane daty (2)")
      fill_in "Notatka (tylko dla admina)", with: "Nieobecność prywatna"
      click_button "Zapisz blokady"
    end
    expect(page).not_to have_css("dialog[open]")
    expect(page).to have_content("Zapisano blokady dla 2 dni")
    expect(ConsultationBlock.count).to eq(2)
    expect(page).to have_button("Zaznacz dni", exact: true)
    visit bookings_path
    %w[2026-10-12 2026-10-14].each do |date|
      panel = find("[data-cally-target='hoursPanel'][data-date='#{date}']", visible: :all)
      expect(panel).not_to have_css("button:not([disabled])", visible: :all)
    end
    expect(page).not_to have_content("Nieobecność prywatna")
  end

  it "keeps the selection and entered values after validation then saves hourly blocks" do
    click_button "Zaznacz dni"
    day("2026-10-13").click
    day("2026-10-14").click
    click_button "Zablokuj zaznaczone"
    within(dialog) do
      uncheck "Całe dni"
      fill_in "Godzina początku", with: Time.zone.parse("2026-10-05 12:00")
      fill_in "Godzina końca", with: Time.zone.parse("2026-10-05 11:00")
      fill_in "Notatka (tylko dla admina)", with: "Zachowana notatka"
      click_button "Zapisz blokady"
      expect(page).to have_content("Koniec musi być później")
      expect(page).to have_field("Notatka (tylko dla admina)", with: "Zachowana notatka")
      expect(page).to have_content("Wybrane daty (2)")
      expect(ConsultationBlock.count).to eq(0)
      fill_in "Godzina końca", with: Time.zone.parse("2026-10-05 13:30")
      click_button "Zapisz blokady"
    end
    expect(page).not_to have_css("dialog[open]")
    expect(ConsultationBlock.count).to eq(2)
    expect(ConsultationBlock.all.all? { |block| !block.all_day? && block.starts_at.hour == 12 && block.ends_at.strftime("%H:%M") == "13:30" }).to be true
  end

  it "edits and deletes existing extra appointments within the day dialog" do
    slot = ConsultationSlot.create!(starts_at: Time.zone.parse("2026-10-17 10:00"))
    visit admin_consultation_calendar_path
    day("2026-10-17").click
    within(dialog) do
      click_link "Edytuj termin"
      fill_in "Godzina rozpoczęcia (Warszawa)", with: Time.zone.parse("2026-10-05 12:00")
      click_button "Zapisz termin"
    end
    expect(page).not_to have_css("dialog[open]")
    expect(slot.reload.starts_at.hour).to eq(12)
    day("2026-10-17").click
    accept_confirm { within(dialog) { click_button "Usuń termin" } }
    expect(page).not_to have_css("dialog[open]")
    expect(ConsultationSlot.exists?(slot.id)).to be false
  end

  it "keeps the displayed month when deleting an entry from the future list" do
    block = ConsultationBlock.create!(starts_at: Time.zone.parse("2026-11-17 00:00"), ends_at: Time.zone.parse("2026-11-18 00:00"), all_day: true, category: "time_off")
    visit admin_consultation_calendar_path
    click_link "Następny miesiąc →"
    expect(page).to have_css('#consultation_calendar_month [data-month-date="2026-11-01"]')
    accept_confirm { within("#consultation_calendar_lists") { click_button "Usuń" } }
    expect(page).to have_content("Usunięto blokadę")
    expect(page).to have_css('#consultation_calendar_month [data-month-date="2026-11-01"]')
    expect(ConsultationBlock.exists?(block.id)).to be false
  end

  it "shows all seven columns and a centered modal on a 390px phone and closes by backdrop" do
    @phone = true
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be true
    tiles = page.evaluate_script("Array.from(document.querySelectorAll('button[data-date]')).slice(0, 7).map(button => button.getBoundingClientRect().toJSON())")
    expect(tiles.map { |tile| tile["top"] }.uniq.size).to eq(1)
    expect(tiles.last["right"]).to be <= 390
    day("2026-10-11").click
    expect(dialog).to have_content("11 października 2026")
    box = page.evaluate_script("document.querySelector('dialog').getBoundingClientRect().toJSON()")
    expect(box["left"] + box["width"] / 2).to be_within(1).of(195)
    expect(box["top"] + box["height"] / 2).to be_within(1).of(422)
    expect(box["width"]).to be <= 358
    page.save_screenshot(Rails.root.join("tmp", "interactive-consultation-mobile.png"))
    page.driver.browser.action.move_to_location(2, 2).click.perform
    expect(page).not_to have_css("dialog[open]")
  end
end
