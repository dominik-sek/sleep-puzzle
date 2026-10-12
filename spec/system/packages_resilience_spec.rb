require "rails_helper"

RSpec.describe "Package page recovery and image viewer", type: :system do
  after do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
    page.driver.browser.execute_cdp("Network.setCacheDisabled", cacheDisabled: false)
    page.driver.browser.execute_cdp("Network.emulateNetworkConditions", offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1)
  end

  %i[pl en].each do |locale|
    it "recovers the #{locale} calendar through its retry action on a phone" do
      allow(GoogleCalendarService).to receive(:call).and_raise(GoogleCalendarService::NotConnected)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 800, deviceScaleFactor: 1, mobile: false)
      visit packages_path(locale: locale == :pl ? nil : locale)

      within("#availability") do
        expect(page).to have_link(I18n.t("offers.instagram_cta", locale: locale))
        expect(page).not_to have_css("calendar-date")
      end
      expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 320
      recovery_targets = page.evaluate_script("[...document.querySelectorAll('#availability a')].map(link => link.getBoundingClientRect().height)")
      expect(recovery_targets).to all(be >= 44)

      # A retry during the same outage must issue another request, too.
      click_link I18n.t("bookings.calendar.retry", locale: locale)
      expect(page).to have_current_path(packages_path(locale: locale == :pl ? nil : locale, calendar_retry: 1))
      allow(GoogleCalendarService).to receive(:call).and_return(instance_double(GoogleCalendarService, busy: []))
      click_link I18n.t("bookings.calendar.retry", locale: locale)

      expect(page).to have_current_path(packages_path(locale: locale == :pl ? nil : locale, calendar_retry: 2))
      expect(URI.parse(page.current_url).fragment).to eq("availability")
      expect(page).to have_css("calendar-date")
      expect(page).to have_text(I18n.t("bookings.calendar.pick_a_day", locale: locale))
      expect(page).not_to have_link(I18n.t("bookings.calendar.retry", locale: locale))
    end
  end

  context "with a comparison photo" do
    before do
      allow(GoogleCalendarService).to receive(:call).and_return(instance_double(GoogleCalendarService, busy: []))
      allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price ])
      create_package
      block = ContentBlock.create!(key: "packages.comparison.image")
      block.image.attach(io: Rails.root.join("app/assets/images/avatar.jpg").open, filename: "comparison.jpg", content_type: "image/jpeg")
      block.image.blob.analyze
    end

    it "fetches viewer code and styles only when the photo is opened" do
      visit packages_path
      expect(page.evaluate_script("performance.getEntriesByType('resource').filter(entry => entry.name.includes('lightbox_viewer')).length")).to eq(0)
      find("#package-comparison a").send_keys(:enter)
      expect(page).to have_css(".pswp:focus")

      viewer_resources = page.evaluate_script("performance.getEntriesByType('resource').filter(entry => entry.name.includes('lightbox_viewer')).map(entry => new URL(entry.name).pathname)")
      expect(viewer_resources).to include(a_string_ending_with(".js"), a_string_ending_with(".css"))
      expect(page.evaluate_script("getComputedStyle(document.querySelector('.pswp')).position")).to eq("fixed")
      expect(page).to have_css("#package-comparison img", visible: :all) { |image| image.evaluate_script("this.complete && this.naturalWidth === 800 && this.naturalHeight === 800") }
    end

    it "reserves the photo's aspect ratio even while the thumbnail cannot load" do
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 800, deviceScaleFactor: 1, mobile: false)
      page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [ "*/representations/*" ])
      visit packages_path
      image = find("#package-comparison img")

      expect(image.evaluate_script("this.getAttribute('width')")).to eq("4168")
      expect(image.evaluate_script("this.getAttribute('height')")).to eq("4168")
      geometry = image.evaluate_script("({width: this.getBoundingClientRect().width, height: this.getBoundingClientRect().height})")
      expect(geometry["width"]).to eq(280)
      expect(geometry["height"]).to eq(280)
      expect(page.evaluate_script("document.documentElement.scrollWidth")).to eq(320)
    end

    it "cancels a pending viewer opening with Escape on a slow connection" do
      page.driver.browser.execute_cdp("Network.enable")
      page.driver.browser.execute_cdp("Network.setCacheDisabled", cacheDisabled: true)
      visit packages_path
      page.driver.browser.execute_cdp("Network.emulateNetworkConditions", offline: false, latency: 800, downloadThroughput: -1, uploadThroughput: -1)
      find("#package-comparison a").send_keys(:enter)
      expect(page).to have_css('#package-comparison a[aria-busy="true"]')
      find("body").send_keys(:escape)
      expect(page).not_to have_css('#package-comparison a[aria-busy="true"]')

      loaded = page.evaluate_async_script(<<~JS)
        const done = arguments[0];
        const deadline = Date.now() + 4000;
        const check = () => {
          const scripts = performance.getEntriesByType('resource').filter(entry => entry.name.includes('lightbox_viewer') && new URL(entry.name).pathname.endsWith('.js'));
          if (scripts.length) done(true);
          else if (Date.now() > deadline) done(false);
          else setTimeout(check, 50);
        };
        check();
      JS
      expect(loaded).to be(true)
      expect(page).not_to have_css(".pswp")
    end

    it "opens the original image if the deferred viewer cannot load" do
      page.driver.browser.execute_cdp("Network.enable")
      page.driver.browser.execute_cdp("Network.setCacheDisabled", cacheDisabled: true)
      page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [ "*lightbox_viewer*.js*" ])
      visit packages_path
      find("#package-comparison a").click

      expect(page).to have_current_path(%r{/rails/active_storage/disk/}, ignore_query: true)
      expect(page).to have_css("body > img")
    end

    %i[pl en].each do |locale|
      it "names the #{locale} viewer and controls and supports keyboard dismissal" do
        visit packages_path(locale: locale == :pl ? nil : locale)
        find("#package-comparison a").send_keys(:enter)

        viewer = find(".pswp[role='dialog']")
        expect(viewer[:"aria-label"]).to eq(I18n.t("lightbox.viewer", locale: locale))
        within(viewer) do
          expect(page).to have_button(I18n.t("lightbox.zoom", locale: locale))
          expect(page).to have_button(I18n.t("lightbox.close", locale: locale))
        end
        expect(page).to have_css(".pswp:focus")
        find("body").send_keys(:escape)
        expect(page).not_to have_css(".pswp")
        expect(page).to have_css("#package-comparison a:focus")
      end
    end

    it "localizes an image-loading failure and keeps dismissal available" do
      page.driver.browser.execute_cdp("Network.enable")
      page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [ "*comparison.jpg*" ])
      visit packages_path(locale: :en)
      find("#package-comparison a").send_keys(:enter)

      expect(page).to have_css(".pswp__error-msg", text: I18n.t("lightbox.error", locale: :en))
      expect(page).to have_css(".pswp:focus")
      click_button I18n.t("lightbox.close", locale: :en)
      expect(page).not_to have_css(".pswp")
    end

    it "zooms the photo instantly when reduced motion is requested" do
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
      visit packages_path
      find("#package-comparison a").click
      image = find(".pswp__img:not(.pswp__img--placeholder)")
      image.click

      expect(page).to have_css(".pswp__zoom-level-indicator", text: "100%")
      expect(page.evaluate_script(<<~JS)).to all(eq("0s"))
        [...document.querySelectorAll('.pswp__zoom-wrap')].map(element => getComputedStyle(element).transitionDuration)
      JS
      expect(page.evaluate_script("getComputedStyle(document.querySelector('.pswp__zoom-level-indicator')).transitionDuration")).to eq("0s")
      click_button I18n.t("lightbox.close")
      expect(page).not_to have_css(".pswp")
    end
  end
end
