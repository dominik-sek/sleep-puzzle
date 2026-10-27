# Run with production-built assets; see docs/frontend-load-2026-10-27.md.
require_relative "../spec/rails_helper"
require "zlib"

RSpec.describe "Production frontend load measurement", type: :system do
  include Warden::Test::Helpers

  after { Warden.test_reset! }

  it "records cold mobile loads against production-built assets" do
    ContentBlock.sync!
    create_product(kind: :audio_process)
    create_package
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_123"), paddle_price(id: "pri_456") ])
    allow(GoogleCalendarService).to receive(:call).and_return(instance_double(GoogleCalendarService, busy: []))
    page.driver.browser.manage.window.resize_to(390, 844)
    browser = page.driver.browser
    browser.execute_cdp("Network.enable")
    browser.execute_cdp("Network.setCacheDisabled", cacheDisabled: true)
    browser.execute_cdp("Network.emulateNetworkConditions", offline: false, latency: 150, downloadThroughput: 200_000, uploadThroughput: 93_750)
    browser.execute_cdp("Emulation.setCPUThrottlingRate", rate: 4)
    result = {}
    { home: root_path, shop: products_path, packages: packages_path, admin: new_admin_product_path }.each do |name, path|
      login_as User.create!(email: "benchmark@example.com", password: "password123", admin: true), scope: :user if name == :admin
      samples = 3.times.map do
        visit path
        expect(page).to have_css("main")
        expect(page).to have_css("calendar-month") if name == :packages
        expect(page).to have_css('[data-sidebar-target="desktopContent"] nav', visible: :all) if name == :admin
        expect(page).to have_css('[data-controller="navbar"]') unless name == :admin
        # All declared controllers must have connected before counting the page's load.
        expect(page.evaluate_script(<<~JS)).to be(true)
          new Promise(resolve => {
            const check = () => {
              const nodes = [...document.querySelectorAll('[data-controller]')];
              const ready = window.Stimulus && nodes.every(e => e.dataset.controller.split(/\\s+/).filter(Boolean).every(id => window.Stimulus.getControllerForElementAndIdentifier(e, id)));
              const editorsReady = !document.querySelector('trix-editor') || Boolean(customElements.get('trix-editor'));
              (ready && editorsReady) ? requestAnimationFrame(() => requestAnimationFrame(() => resolve(true))) : setTimeout(check, 20);
            };
            check();
          })
        JS
        metrics = page.evaluate_script(<<~JS)
          (() => {
            const nav = performance.getEntriesByType('navigation')[0];
            return { domContentLoaded: nav.domContentLoadedEventEnd, load: nav.loadEventEnd,
              fcp: performance.getEntriesByName('first-contentful-paint')[0]?.startTime,
              js: performance.getEntriesByType('resource').filter(r => /\\/vite-benchmark\\/.*\\.js(?:$|\\?)/.test(r.name)).map(r => ({path:new URL(r.name).pathname, bytes:r.decodedBodySize})) };
          })()
        JS
        expect(metrics["js"]).not_to be_empty
        metrics["js_raw_bytes"] = metrics["js"].sum { |r| File.size(Rails.root.join("public", r["path"].delete_prefix("/"))) }
        metrics["js_gzip_bytes"] = metrics["js"].sum { |r| Zlib.gzip(File.binread(Rails.root.join("public", r["path"].delete_prefix("/")))).bytesize }
        metrics
      end
      result[name] = samples
    end
    File.write(Rails.root.join("tmp", "frontend-load-#{ENV.fetch('LOAD_LABEL', 'current')}.json"), JSON.pretty_generate(result))
  end
end
