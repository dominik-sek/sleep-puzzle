require "rails_helper"

RSpec.describe "Audio process landing interactions", type: :system do
  before do
    ContentBlock.sync!
    @product = create_product(name: "Proces dla rodziców", kind: :audio_process)
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456") ])
  end

  after { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  def add_selector
    'button[aria-label^="Dodaj do koszyka"]'
  end

  def remove_selector
    'button[aria-label^="Usuń z koszyka"]'
  end

  [ 1440, 390 ].each do |width|
    it "keeps the named program H2 and keyboard cart focus at #{width}px" do
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
        width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit audio_process_path
      expect(page).to have_css("main h1", count: 1)
      heading_id = "chapter_outline_heading_product_#{@product.id}"
      expect(page).to have_css("section[aria-labelledby='#{heading_id}'] h2##{heading_id}", text: "Program audioprocesu")

      find(add_selector).send_keys(:enter)
      expect(page).to have_css("#{remove_selector}:focus")
      expect(page).to have_link("Przejdź do koszyka")
      expect(page).to have_css('[aria-live="polite"]', text: "Dodano do koszyka")
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
