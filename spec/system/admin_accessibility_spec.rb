require "rails_helper"

RSpec.describe "Admin navigation accessibility", type: :system do
  include Warden::Test::Helpers

  before do
    login_as User.create!(email: "navigation-admin@example.com", password: "password123", admin: true), scope: :user
    allow(PaddlePriceCatalogService).to receive(:call).and_return([])
  end

  after { Warden.test_reset! }

  it "contains mobile focus, closes with Escape, and clears the content header" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_products_path
    opener = '[data-sidebar-target="mobileToggle"]'
    expect(page).to have_css(opener)
    geometry = page.evaluate_script(<<~JS)
      (() => {
        const menu = document.querySelector('#{opener}').getBoundingClientRect();
        const title = document.querySelector('main h1').getBoundingClientRect();
        return { width: menu.width, height: menu.height, clear: title.top >= menu.bottom };
      })()
    JS
    expect(geometry).to include("width" => 44, "height" => 44, "clear" => true)
    find(opener).send_keys(:enter)
    expect(page).to have_css('dialog[open] button[aria-label="Zamknij nawigację"]:focus')
    20.times do
      page.driver.browser.action.send_keys(:tab).perform
      expect(page.evaluate_script("Boolean(document.activeElement.closest('dialog[open]'))")).to be(true)
    end
    page.driver.browser.action.send_keys(:escape).perform
    expect(page).not_to have_css("dialog[open]")
    expect(page).to have_css("#{opener}:focus")

    find(opener).click
    within("dialog[open]") { click_link "Produkty" }
    expect(page).not_to have_css("dialog[open]")
    expect(page).to have_css("#{opener}[aria-expanded='false']")
  end

  it "uses readable hints, complete editor names and 44px language tabs" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit new_admin_article_path
    expect(page).to have_field("Tytuł — Polski")
    expect(page).to have_field("Adres (slug)")
    expect(page.evaluate_script("getComputedStyle(document.querySelector('label[for=record-slug]')).color")).to eq("rgb(155, 148, 138)")
    sizes = page.evaluate_script("Array.from(document.querySelectorAll('[data-article-editor-target=languageTab]')).map(e => e.getBoundingClientRect().height)")
    expect(sizes).to all(be >= 44)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
    page.save_screenshot(Rails.root.join("tmp/admin-accessibility-mobile.png"))

    page.driver.browser.manage.window.resize_to(320, 740)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)

    page.driver.browser.manage.window.resize_to(1280, 900)
    expect(page).not_to have_css('[data-sidebar-target="mobileToggle"]')
    expect(page).to have_css('[data-sidebar-target="desktopContent"] nav')
    page.save_screenshot(Rails.root.join("tmp/admin-accessibility-desktop.png"))
  end

  it "closes an open mobile dialog when crossing the desktop breakpoint" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_products_path
    find('[data-sidebar-target="mobileToggle"]').click
    expect(page).to have_css("dialog[open]")
    page.driver.browser.manage.window.resize_to(1280, 900)
    expect(page).not_to have_css("dialog[open]")
    expect(page).to have_css('[data-sidebar-target="desktopContent"] nav')
  end

  it "updates language on Turbo entry and honours reduced motion" do
    visit root_path(locale: :en)
    expect(page.evaluate_script("document.documentElement.lang")).to eq("en")
    page.execute_script("Turbo.visit(arguments[0])", admin_products_path)
    expect(page).to have_current_path(admin_products_path)
    expect(page.evaluate_script("document.documentElement.lang")).to eq("pl")
    page.driver.browser.manage.window.resize_to(390, 844)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    find('[data-sidebar-target="mobileToggle"]').click
    expect(page).to have_css("dialog[open]")
    expect(page.evaluate_script("getComputedStyle(document.querySelector('[data-sidebar-target=mobilePanel]')).transitionDuration")).to eq("0s")
    page.driver.browser.action.send_keys(:escape).perform
    expect(page).not_to have_css("dialog[open]")
    expect(page).to have_css('[data-sidebar-target="mobileToggle"]:focus')
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end
end
