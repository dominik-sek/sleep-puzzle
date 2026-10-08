require "rails_helper"

RSpec.describe "Package card layout", type: :system do
  it "keeps three cards and their actions aligned on a laptop" do
    allow(GoogleCalendarService).to receive(:call).and_return(instance_double(GoogleCalendarService, busy: []))
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price ])

    3.times do |index|
      package = build_package(name: "Pakiet #{index + 1}", position: index)
      package.assign_translation_list(:highlights, :pl, Array.new(index + 1, "Konsultacja i wsparcie rodziców"))
      package.save!
    end

    page.driver.browser.manage.window.resize_to(900, 900)
    visit packages_path
    expect(page).to have_css('[id^="package_"]', count: 3)

    cards = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('[id^="package_"]')].map(card => {
        const box = card.getBoundingClientRect();
        const button = card.querySelector('a[aria-label^="Zobacz terminy"]');
        return { top: box.top, width: box.width, buttonTop: button.getBoundingClientRect().top };
      })
    JS

    expect(cards.map { |card| card["top"].round }.uniq.size).to eq(1)
    expect(cards.map { |card| card["buttonTop"].round }.uniq.size).to eq(1)
    expect(cards.map { |card| card["width"] }.max).to be <= 376
  end

  [ 390, 900, 1440 ].each do |width|
    it "keeps realistic package cards compact at #{width}px" do
      allow(GoogleCalendarService).to receive(:call).and_return(instance_double(GoogleCalendarService, busy: []))
      prices = [ "135000", "155000", "190000" ].each_with_index.map { |amount, index| paddle_price(id: "pri_preview_#{index}", amount: amount) }
      allow(PaddlePriceCatalogService).to receive(:call).and_return(prices)
      manifest = JSON.parse(Rails.root.join("config/package_copy_refresh.json").read)
      manifest.fetch("packages").each_with_index do |entry, index|
        package = build_package(name: entry.fetch("label"), duration: entry.fetch("duration"), position: index, paddle_price_id: prices[index].id)
        entry.fetch("replacement").each do |field, locales|
          if Package.translated_list_fields.include?(field)
            package.assign_translation_list(field, :pl, locales.fetch("pl"))
          else
            package.assign_translation(field, :pl, locales.fetch("pl"))
          end
        end
        package.save!
      end
      ContentBlock.create!(key: "packages.shared.body", body_pl: manifest.fetch("shared_body_pl"))
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1300, deviceScaleFactor: 1, mobile: false)
      visit packages_path
      expect(page).to have_css('a[aria-label^="Zobacz terminy"]', count: 3)
      dimensions = page.evaluate_script(<<~JS)
        ({ viewport: window.innerWidth, document: document.documentElement.scrollWidth,
           cards: [...document.querySelectorAll('[id^="package_"]')].map(card => {
             const rect = card.getBoundingClientRect();
             return { height: rect.height, top: rect.top, width: rect.width };
           }) })
      JS
      expect(dimensions["document"]).to be <= dimensions["viewport"]
      expect(dimensions["viewport"]).to eq(width)
      expect(dimensions["cards"].map { |card| card["height"] }.max).to be < 1200
      expect(dimensions["cards"].map { |card| card["top"].round }.uniq.size).to eq(width == 390 ? 3 : 1)
      expect(page).to have_css("dialog:not([open])", count: 3, visible: :all)
      expect(page).not_to have_css("#package-details")
      expect(page).not_to have_css("#package-shared")
      page.save_screenshot(Rails.root.join("tmp/package-copy/layout-#{width}.png"))
      modal_height = width == 390 ? 844 : 900
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: modal_height, deviceScaleFactor: 1, mobile: false)
      second = Package.ordered.second
      find("button[aria-controls='package-details-#{second.id}']").click
      expect(page).to have_css("#package-details-#{second.id}[open] [data-dialog-heading]:focus")
      within("dialog[open]") { expect(page).to have_text("Telegramie") }
      box = page.evaluate_script("document.querySelector('dialog[open]').getBoundingClientRect().toJSON()")
      expect(box["width"]).to be <= [ 800, width - 32 ].min
      expect(box["height"]).to be <= modal_height - 32
      expect(box["left"]).to be >= 0
      expect(box["top"]).to be >= 0
      expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= width
      scroll_y = page.evaluate_script("window.scrollY")
      expect(page.evaluate_script("document.querySelector('dialog[open] .package-details-scroll').scrollHeight > document.querySelector('dialog[open] .package-details-scroll').clientHeight")).to be(true)
      page.save_screenshot(Rails.root.join("tmp/package-copy/details-#{width}.png"))
      within("dialog[open]") { click_button "Zamknij" }
      expect(page).not_to have_css("dialog[open]")
      expect(page.evaluate_script("window.scrollY")).to be_within(1).of(scroll_y)
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    end
  end
end
