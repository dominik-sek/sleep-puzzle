require "rails_helper"

RSpec.describe "Admin package preview", type: :system do
  include Warden::Test::Helpers

  before do
    allow(PaddlePriceCatalogService).to receive(:call).and_return([
      paddle_price,
      paddle_price(id: "pri_second", amount: "49900")
    ])
    login_as User.create!(email: "preview@example.com", password: "password123", admin: true), scope: :user
  end

  after { Warden.test_reset! }

  it "updates the card and full details as the admin types without saving" do
    package = create_package(name: "Zapisany pakiet", duration: 4)
    page.driver.browser.manage.window.resize_to(1440, 1000)
    visit edit_admin_package_path(package)
    expect(page).to have_css("#package-preview h2", text: "Zapisany pakiet")

    fill_in "record-name-pl", with: "Nowy opis pakietu"
    fill_in "record-for_whom-pl", with: "Dla zmęczonych rodziców"
    fill_in "record-highlights-pl", with: (1..6).map { |n| "Wyróżnik #{n}" }.join("\n")
    fill_in "record-core-pl", with: "Konsultacja\n\n  Plan snu  "
    fill_in "record-organization-pl", with: "Przygotuj dzienniczek\n\nNapisz na Telegramie"
    fill_in "record-duration", with: "6"
    select "Pakiet - Jednorazowo - 499,00 PLN", from: "record-paddle-price-id"

    within("#package-preview") do
      expect(page).to have_css("h2", text: "Nowy opis pakietu")
      expect(page).to have_text("Dla zmęczonych rodziców")
      expect(page).to have_text("6 tygodni")
      expect(page).to have_text("499,00 PLN")
      expect(page).to have_css("li", count: 5)
      expect(page).not_to have_text("Wyróżnik 6")
      expect(page).to have_button("Zobacz terminy", disabled: true)
      click_button "Poznaj szczegóły"
    end
    within("dialog[open]") do
      expect(page).to have_text("Wyróżnik 6")
      expect(page).to have_text("Konsultacja", normalize_ws: true)
      expect(page).to have_text("Plan snu")
      expect(page).to have_text("Przygotuj dzienniczek")
      expect(page).to have_text("Napisz na Telegramie")
      click_button "Zamknij"
    end
    expect(package.reload.name).to eq("Zapisany pakiet")
    expect(package.duration).to eq(4)

    fill_in "record-for_whom-pl", with: "a" * 221
    within("#package-preview") do
      expect(page).to have_text("Podgląd aktualny")
      expect(page).not_to have_text("Dla zmęczonych rodziców")
      click_button "Poznaj szczegóły"
    end
    within("dialog[open]") do
      expect(page).to have_text("a" * 221)
      click_button "Zamknij"
    end
    click_button "Zapisz pakiet"
    expect(page).to have_current_path(admin_packages_path)
    expect(package.reload.name).to eq("Nowy opis pakietu")
  end

  it "switches languages and falls back to Polish while creating a new package" do
    visit new_admin_package_path
    fill_in "record-name-pl", with: "Polski pakiet"
    fill_in "record-name-en", with: "English package"
    fill_in "record-for_whom-pl", with: "Polski opis"
    fill_in "record-highlights-pl", with: "Polski wyróżnik"
    select "EN", from: "package-preview-locale"

    within("#package-preview") do
      expect(page).to have_css('[lang="en"] h2', text: "English package")
      expect(page).to have_text("Polski opis")
      expect(page).to have_text("Polski wyróżnik")
    end
    fill_in "record-for_whom-en", with: "English summary"
    within("#package-preview") { expect(page).to have_text("English summary") }
    select "PL", from: "package-preview-locale"
    within("#package-preview") do
      expect(page).to have_css('[lang="pl"] h2', text: "Polski pakiet")
      expect(page).to have_text("Polski opis")
      expect(page).not_to have_text("English summary")
    end
    expect(Package.count).to eq(0)
  end

  it "allows retrying a failed preview while keeping the form usable" do
    visit edit_admin_package_path(create_package)
    page.execute_script("window.originalFetch = window.fetch; window.fetch = () => Promise.reject(new Error('Offline'))")
    fill_in "record-name-pl", with: "Niezapisana nazwa"
    within("#package-preview") { expect(page).to have_text("Nie udało się odświeżyć podglądu") }
    expect(page).to have_field("record-name-pl", with: "Niezapisana nazwa")
    page.execute_script("window.fetch = window.originalFetch")
    within("#package-preview") do
      click_button "Odśwież podgląd"
      expect(page).to have_css("h2", text: "Niezapisana nazwa")
      expect(page).to have_text("Podgląd aktualny")
    end
  end

  it "keeps the preview beside the form on desktop and reachable on mobile" do
    package = create_package(name: "Spokojne noce", duration: 4)
    package.assign_translation(:for_whom, :pl, "Dla rodziców, którzy potrzebują planu i wsparcia w codziennych zmianach.")
    package.assign_translation_list(:highlights, :pl, [ "Indywidualny plan snu", "Konsultacja i bieżący kontakt" ])
    package.save!

    [ 1440, 390 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: false)
      visit edit_admin_package_path(package)
      expect(page).to have_css("#package-preview h2", text: "Spokojne noce")
      dimensions = page.evaluate_script(<<~JS)
        (() => {
          const main = document.querySelector("main");
          const form = document.querySelector('[data-package-preview-target="form"]').getBoundingClientRect();
          const preview = document.querySelector("#package-preview").getBoundingClientRect();
          return { width: main.clientWidth, scrollWidth: main.scrollWidth,
                   formRight: form.right, formBottom: form.bottom,
                   previewLeft: preview.left, previewTop: preview.top };
        })()
      JS
      expect(dimensions["scrollWidth"]).to be <= dimensions["width"]
      if width == 1440
        expect(dimensions["previewLeft"]).to be > dimensions["formRight"]
        page.evaluate_script("document.querySelector('main').scrollTop = 500")
        expect(page.evaluate_script("document.querySelector('#package-preview').getBoundingClientRect().top")).to be_within(1).of(32)
        page.evaluate_script("document.querySelector('main').scrollTop = 0")
      else
        expect(dimensions["previewTop"]).to be > dimensions["formBottom"]
        click_link "Przejdź do podglądu"
        expect(page).to have_css("#package-preview") { |preview| preview.evaluate_script("this.getBoundingClientRect().top") < 1000 }
      end
      page.save_screenshot(Rails.root.join("tmp/package-preview/admin-#{width}.png"))
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    end
  end
end
