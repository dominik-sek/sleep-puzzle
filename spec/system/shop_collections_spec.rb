require "rails_helper"

RSpec.describe "Shop category navigation", type: :system do
  before do
    ContentBlock.sync!
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456") ])
    @program = create_product(name: "Proces dla rodziców", kind: :audio_process)
    @story = create_product(name: "Bajka o spokojnym wieczorze", description: "Opowieść. " * 40)
    create_product(name: "Długanazwa" * 15, kind: :audio_process)
    create_package(name: "Wsparcie 1:1")
  end

  after { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  [ 1440, 390 ].each do |width|
    it "opens the stories collection from navigation at #{width}px" do
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
        width: width, height: 900, deviceScaleFactor: 1, mobile: false)
      visit products_path

      if width < 1024
        find('button[aria-label="Menu"]').send_keys(:enter)
        within("#mobile-menu-content") { click_link "Bajki audio" }
        expect(page).to have_css('button[aria-label="Menu"][aria-expanded="false"]')
      else
        within('nav[data-controller="navbar"]') { click_link "Bajki audio", match: :first }
      end

      expect(page).to have_current_path(stories_path)
      expect(page).to have_css("main h1", text: "Bajki audio")
      expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
      within("main") do
        expect(page).to have_css("h2", text: @story.name)
        expect(page).not_to have_text(@program.name)
        click_link @story.name
      end
      expect(page).to have_current_path(product_path(@story))
    end
  end

  [ nil, :en ].each do |locale|
    it "keeps all local shop jumps below the navbar and focuses their destination in #{locale || :pl}" do
      visit products_path(locale: locale)
      %w[audio-processes stories packages].each do |anchor|
        find("main nav a[href='##{anchor}']").send_keys(:enter)
        expect(page).to have_current_path(/#{Regexp.escape(products_path(locale: locale, anchor: anchor))}\z/, url: true)
        expect(page).to have_css("##{anchor}:focus")
        expect(page.evaluate_script("document.getElementById('#{anchor}-title').getBoundingClientRect().top >= document.querySelector('nav[data-controller=navbar]').getBoundingClientRect().bottom")).to be(true)
      end
    end
  end

  it "preserves the English stories anchor and empty state" do
    @story.update!(published: false)
    visit products_path(locale: :en, anchor: "stories")

    expect(page).to have_css("#stories h2", text: "Audio stories")
    expect(page).to have_text("Audio stories will appear here soon.")
    expect(page).not_to have_css("#stories article")
  end

  it "keeps the catalogue within a narrow viewport with doubled text size" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: 390, height: 900, deviceScaleFactor: 1, mobile: false)
    visit products_path
    page.execute_script("document.documentElement.style.fontSize = '200%'")

    expect(page).to have_css("#stories h3", text: @story.name)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
  end
end
