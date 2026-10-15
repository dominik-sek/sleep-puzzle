require "rails_helper"

RSpec.describe "Admin product URL controls", type: :system do
  include Warden::Test::Helpers

  before do
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456") ])
    login_as User.create!(email: "slug-owner@example.com", password: "password123", admin: true), scope: :user
    @product = create_product(name: "Sowa")
  end

  after do
    Warden.test_reset!
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  it "previews an unsaved name and saves the URL only with the product" do
    visit edit_admin_product_path(@product)
    fill_in "record-name-pl", with: "Nowa sowa"
    find("button", text: "Wygeneruj adres z nazwy").send_keys(:enter)
    expect(page).to have_css('[data-product-slug-target="path"]', text: "/stories/nowa-sowa")
    expect(@product.reload.slug).to eq("sowa")
    expect(@product.name).to eq("Sowa")
    click_button "Zapisz produkt"
    expect(page).to have_current_path(admin_products_path)
    expect(@product.reload.slug).to eq("nowa-sowa")
    expect(@product.slug_histories.pluck(:slug)).to match_array(%w[sowa nowa-sowa])
  end

  it "invalidates a preview after another name edit and lets the owner cancel by keyboard" do
    visit edit_admin_product_path(@product)
    fill_in "record-name-pl", with: "Pierwszy szkic"
    click_button "Wygeneruj adres z nazwy"
    expect(page).to have_css('[data-product-slug-target="path"]', text: "pierwszy-szkic")
    fill_in "record-name-pl", with: "Drugi szkic"
    expect(page).not_to have_css('[data-product-slug-target="pending"]')
    click_button "Wygeneruj adres z nazwy"
    expect(page).to have_css('[data-product-slug-target="path"]', text: "drugi-szkic")
    find("button", text: "Zachowaj obecny adres").send_keys(:enter)
    expect(page).to have_css('[data-product-slug-target="generate"]:focus')
    click_button "Zapisz produkt"
    expect(page).to have_current_path(admin_products_path)
    expect(@product.reload.slug).to eq("sowa")
    expect(@product.name).to eq("Drugi szkic")
  end

  it "allows retrying a preview error without losing the edited name" do
    visit edit_admin_product_path(@product)
    fill_in "record-name-pl", with: "Nowa sowa"
    page.execute_script("window.originalFetch = window.fetch; window.fetch = () => Promise.reject(new Error('Offline'))")
    click_button "Wygeneruj adres z nazwy"
    expect(page).to have_text("Nie udało się wygenerować adresu")
    expect(page).to have_field("record-name-pl", with: "Nowa sowa")
    expect(@product.reload.slug).to eq("sowa")
    page.execute_script("window.fetch = window.originalFetch")
    click_button "Wygeneruj adres z nazwy"
    expect(page).to have_css('[data-product-slug-target="path"]', text: "nowa-sowa")
  end

  it "wraps the preview and keeps the controls usable on desktop and mobile" do
    [ [ 1440, "desktop" ], [ 390, "mobile" ] ].each do |width, label|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: false)
      visit edit_admin_product_path(@product)
      fill_in "record-name-pl", with: "Spokojny sen — długa nazwa programu z opowieściami dla całej rodziny"
      click_button "Wygeneruj adres z nazwy"
      expect(page).to have_css('[data-product-slug-target="path"]', text: "spokojny-sen-dluga-nazwa")
      expect(page.evaluate_script("document.querySelector('main').scrollWidth <= document.querySelector('main').clientWidth")).to be(true)
      expect(find("button", text: "Wygeneruj adres z nazwy").native.rect.height).to be >= 44
      directory = Rails.root.join(".impeccable/review/product-slug")
      FileUtils.mkdir_p(directory)
      page.save_screenshot(directory.join("#{label}.png"))
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    end
  end
end
