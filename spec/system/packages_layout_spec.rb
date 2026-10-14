require "rails_helper"

RSpec.describe "Package card layout", type: :system do
  include ActiveSupport::Testing::TimeHelpers

  after do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Emulation.setCPUThrottlingRate", rate: 1)
    page.driver.browser.execute_cdp("Emulation.setTimezoneOverride", timezoneId: "")
  end

  [ "2026-10-05", "2026-10-31", "2026-12-31" ].each do |date|
    it "lets a phone visitor pick a real calendar day on #{date}" do
      travel_to Time.zone.parse("#{date} 07:00") do
        allow(GoogleCalendarService).to receive(:call).and_return(instance_double(GoogleCalendarService, busy: []))
        allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price ])
        2.times do |index|
          package = build_package(name: "Pakiet #{index + 1}", position: index)
          package.save!
        end
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 800, deviceScaleFactor: 1, mobile: false)
        page.driver.browser.execute_cdp("Emulation.setCPUThrottlingRate", rate: 6)
        page.driver.browser.execute_cdp("Emulation.setTimezoneOverride", timezoneId: "UTC")
        visit packages_path

        # A raw "first enabled button" can belong to an intermediate month render.
        # Choose a date from server availability and wait for its actual day cell.
        available_date = JSON.parse(find("#availability")["data-cally-available-dates-value"]).first
        expect(available_date).to be_present
        label = page.evaluate_script(<<~JS, available_date)
          new Intl.DateTimeFormat('pl', { month: 'long', day: 'numeric', timeZone: 'UTC' })
            .format(new Date(arguments[0] + 'T00:00:00Z'))
        JS
        expect(page).to have_css("calendar-month", wait: 5) do |month|
          month.evaluate_script(<<~JS, available_date, label)
            (() => {
              const calendar = this.closest('calendar-date');
              const day = this.shadowRoot?.querySelector(`button[aria-label="${arguments[1]}"]`);
              return calendar.focusedDate === arguments[0] && calendar.locale === 'pl' &&
                Boolean(this.shadowRoot?.querySelector('button[aria-disabled="true"]')) &&
                day && !day.disabled && day.getAttribute('aria-disabled') !== 'true';
            })()
          JS
        end
        day = find("calendar-month").native.shadow_root.find_element(css: %(button[aria-label="#{label}"]:not([disabled]):not([aria-disabled='true'])))
        day.click
        selected_panel = %([data-cally-target="hoursPanel"][data-date="#{available_date}"]:not([hidden]))
        expect(page).to have_css("#{selected_panel} button:not(:disabled)")
        expect(page.evaluate_script("document.querySelector('calendar-date').value")).to eq(available_date)
        hour = nil
        within(selected_panel) do
          button = find("button:not(:disabled)", match: :first)
          hour = button["data-hour"]
          button.click
        end
        href = URI.parse(find_link(I18n.t("offers.continue_booking"))[:href])
        expect(href.path).to eq(bookings_path)
        expect(Rack::Utils.parse_query(href.query)).to include("date" => available_date, "hour" => hour)
      end
    end
  end

  it "keeps three cards and their actions aligned on a laptop" do
    allow(GoogleCalendarService).to receive(:call).and_return(instance_double(GoogleCalendarService, busy: []))
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price ])

    3.times do |index|
      package = build_package(name: "Pakiet #{index + 1}", position: index)
      package.assign_translation_list(:highlights, :pl, Array.new(index + 1, "Konsultacja i wsparcie rodziców"))
      package.save!
    end

    page.driver.browser.manage.window.resize_to(1200, 900)
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

  [ 320, 390, 768, 900, 1024, 1440 ].each do |width|
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
        ({ viewport: window.innerWidth, contentWidth: document.documentElement.clientWidth,
           document: document.documentElement.scrollWidth,
           cards: [...document.querySelectorAll('[id^="package_"]')].map(card => {
             const rect = card.getBoundingClientRect();
             return { height: rect.height, top: rect.top, width: rect.width };
           }) })
      JS
      expect(dimensions["document"]).to be <= dimensions["contentWidth"]
      expect(dimensions["viewport"]).to eq(width)
      expect(dimensions["cards"].map { |card| card["height"] }.max).to be < 1200
      expected_rows = width < 640 ? 3 : (width < 1024 ? 2 : 1)
      expect(dimensions["cards"].map { |card| card["top"].round }.uniq.size).to eq(expected_rows)
      # Desktop scrollbars reduce the available width even under phone-sized emulation.
      scrollbar_width = dimensions["viewport"] - dimensions["contentWidth"]
      expect(dimensions["cards"].map { |card| card["width"] }.min).to be >= 280 - scrollbar_width
      calendar_targets = page.evaluate_script(<<~JS)
        [...document.querySelectorAll('calendar-date, calendar-month')].flatMap(calendar =>
          [...calendar.shadowRoot.querySelectorAll('button')].map(button => {
            const rect = button.getBoundingClientRect();
            return { width: rect.width, height: rect.height, left: rect.left, right: rect.right };
          }))
      JS
      expect(calendar_targets).not_to be_empty
      calendar_targets.each do |target|
        expect(target["width"]).to be >= 44
        expect(target["height"]).to be >= 44
        expect(target["left"]).to be >= 0
        expect(target["right"]).to be <= width
      end
      expect(page).to have_css("dialog:not([open])", count: 3, visible: :all)
      expect(page).not_to have_css("#package-details")
      expect(page).not_to have_css("#package-shared")
      page.save_screenshot(Rails.root.join("tmp/package-copy/layout-#{width}.png"))
      modal_height = width == 390 ? 844 : 900
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: modal_height, deviceScaleFactor: 1, mobile: false)
      second = Package.ordered.second
      opener = find("button[aria-controls='package-details-#{second.id}']")
      opener.execute_script("this.scrollIntoView({ block: 'center', behavior: 'instant' })")
      # Compare the same page layout before opening and after closing the dialog.
      scroll_y = page.evaluate_script("window.scrollY")
      opener.click
      expect(page).to have_css("#package-details-#{second.id}[open] [data-dialog-heading]:focus")
      within("dialog[open]") { expect(page).to have_text("Telegramie") }
      box = page.evaluate_script("document.querySelector('dialog[open]').getBoundingClientRect().toJSON()")
      expect(box["width"]).to be <= [ 800, width - 32 ].min
      expect(box["height"]).to be <= modal_height - 32
      expect(box["left"]).to be >= 0
      expect(box["top"]).to be >= 0
      expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= width
      expect(page.evaluate_script("document.querySelector('dialog[open] .package-details-scroll').scrollHeight > document.querySelector('dialog[open] .package-details-scroll').clientHeight")).to be(true)
      page.save_screenshot(Rails.root.join("tmp/package-copy/details-#{width}.png"))
      within("dialog[open]") { click_button "Zamknij" }
      expect(page).not_to have_css("dialog[open]")
      expect(page.evaluate_script("window.scrollY")).to be_within(1).of(scroll_y)
    end
  end
end
