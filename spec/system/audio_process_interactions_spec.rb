require "rails_helper"

RSpec.describe "Audio process collection interactions", type: :system do
  before do
    ContentBlock.sync!
    @product = create_product(name: "Proces dla rodziców", kind: :audio_process)
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456") ])
  end

  after { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  def add_selector
    "#cart_toggle_product_#{@product.id} button[aria-label^='Dodaj do koszyka']"
  end

  def remove_selector
    "#cart_toggle_product_#{@product.id} button[aria-label^='Usuń z koszyka']"
  end

  [ 1440, 390 ].each do |width|
    it "links every program and keeps keyboard cart focus at #{width}px" do
      other = create_product(name: "Drugi proces", kind: :audio_process)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
        width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit audio_process_path
      expect(page).to have_css("main h1", count: 1)
      expect(page).to have_css("main h2 a[href='#{product_path(@product)}']", text: @product.name)

      find(add_selector).send_keys(:enter)
      expect(page).to have_css("#{remove_selector}:focus")
      expect(page).to have_css("#cart_toggle_product_#{@product.id} [aria-live='polite']", text: "Dodano")
      expect(page).to have_css("#cart_toggle_product_#{other.id} button[aria-label^='Dodaj do koszyka']")
      expect(page.evaluate_script("document.activeElement.matches(':focus-visible')")).to be(true)

      find(remove_selector).send_keys(:space)
      expect(page).to have_css("#{add_selector}:focus")
      expect(page).not_to have_link("Przejdź do koszyka")
      expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
    end
  end

  it "does not focus the replacement button after pointer activation" do
    visit audio_process_path
    find(add_selector).click
    expect(page).to have_css(remove_selector)
    expect(page).not_to have_css("#{remove_selector}:focus")
  end

  it "does not pull focus back after the visitor tabs away during a slow response" do
    allow_any_instance_of(CartItemsController).to receive(:create).and_wrap_original do |action|
      sleep 0.3
      action.call
    end
    visit audio_process_path
    find(add_selector).send_keys(:enter)
    page.driver.browser.action.send_keys(:tab).perform
    expect(page).to have_css(remove_selector)
    expect(page).not_to have_css("#{remove_selector}:focus")
  end

  it "preserves keyboard focus on the shared shop toggle" do
    visit products_path
    find(add_selector).send_keys(:enter)
    expect(page).to have_css("#{remove_selector}:focus")
    find(remove_selector).send_keys(:enter)
    expect(page).to have_css("#{add_selector}:focus")
  end
end
