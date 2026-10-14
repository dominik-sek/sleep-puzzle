require "rails_helper"

RSpec.describe "Audio process topic disclosure", type: :system do
  before do
    ContentBlock.sync!
    @product = create_product(kind: :audio_process, long_description: "Dla rodziców szukających wsparcia.")
    @product.update!(includes_pl: "<p>Nagrania do słuchania we własnym tempie.</p><p>Możesz do nich wracać.</p><ul><li><strong>Rytm dnia</strong> i rutyna.</li><li>Warunki dostępu pozostają dostępne.</li></ul>")
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456") ])
  end

  after do
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: false)
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  [ :pl, :en ].each do |locale|
    it "shows all topics by keyboard without JavaScript in #{locale} on mobile" do
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
        width: 390, height: 844, deviceScaleFactor: 1, mobile: false)
      page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: true)
      visit product_path(@product, locale: locale == :en ? :en : nil)
      more = locale == :en ? "Show all topics" : "Zobacz wszystkie tematy"
      less = locale == :en ? "Hide the topics" : "Zwiń listę tematów"
      title = locale == :en ? "What is included" : "Co obejmuje"

      expect(page).to have_css("h2#includes_heading_product_#{@product.id}", text: title)
      expect(page).to have_text("Nagrania do słuchania we własnym tempie.")
      expect(page).to have_text("Dla rodziców szukających wsparcia.")
      expect(page).not_to have_css("details .audio-includes")
      find("summary", text: more).send_keys(:enter)
      expect(page).to have_css("details[open] .audio-includes li strong", text: "Rytm dnia")
      expect(page).to have_text("Warunki dostępu pozostają dostępne.")
      expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
      find("summary", text: less).send_keys(:space)
      expect(page).not_to have_css("details[open]")
      expect(page).to have_css("summary:focus", text: more)
    end
  end

  it "shows short CMS content directly" do
    @product.update!(includes_pl: "<p>Jeden krótki opis.</p>")
    visit product_path(@product)

    expect(page).to have_text("Jeden krótki opis.")
    expect(page).not_to have_css("summary")
  end
end
