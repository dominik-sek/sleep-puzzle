require "rails_helper"

RSpec.describe "Shop recommendation and audio shelf", type: :system do
  before do
    allow(PaddlePriceCatalogService).to receive(:call).and_return([
      paddle_price(id: "pri_first", amount: "135000"),
      paddle_price(id: "pri_middle", amount: "155000"),
      paddle_price(id: "pri_last", amount: "185000"),
      paddle_price(id: "pri_456", amount: "49700")
    ])
    [
      [ "1. ELASTYCZNY + AUDIOPROCES", "pri_first", 2, "To najbardziej elastyczna forma współpracy z korektami do planu po każdej rozmowie" ],
      [ "2. SPOKOJNY RYTM", "pri_middle", 5, "Plan na spokojniejsze wieczory i 5 tygodni mojego wsparcia we wprowadzaniu zmian." ],
      [ "3. SYSTEM RODZINY", "pri_last", 7, "7 tygodni wspólnej pracy nad snem i możliwość zachowania niewykorzystanego wsparcia na później." ]
    ].each_with_index do |(name, price, duration, highlight), position|
      package = build_package(name: name, paddle_price_id: price, duration: duration, position: position)
      package.assign_translation_list(:highlights, :pl, [ highlight ])
      package.save!
    end
    @program = create_product(name: '"Idź już spać" - audioproces', kind: :audio_process,
      expected_chapter_count: 2,
      description: "Kawałek po kawałku pomogę Ci zrozumieć, co wpływa na zasypianie, drzemki i nocne pobudki. Dowiesz się, od czego zacząć, jakie zmiany możesz wprowadzić we własnym tempie.")
  end

  after { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  def viewport(width)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: width, height: 900, deviceScaleFactor: 1, mobile: false)
  end

  [ 1440, 768, 390 ].each do |width|
    it "matches the approved hierarchy without overflow at #{width}px" do
      viewport(width)
      visit products_path
      expect(page).to have_css(".shop-package-feature h3", text: "2. SPOKOJNY RYTM")
      expect(page).to have_css(".shop-package-row", count: 2)
      expect(page).to have_css(".shop-shelf-single article", count: 1)
      expect(page).not_to have_css("#stories article")
      expect(page).not_to have_css("main nav")
      expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
      expect(page.evaluate_script(<<~JS)).to be(true)
        (() => {
          const card = document.querySelector('.shop-shelf-single article').getBoundingClientRect();
          const section = document.querySelector('#audio-processes').getBoundingClientRect();
          return Math.abs(card.width - section.width) < 2;
        })()
      JS
      capture = page.driver.browser.execute_cdp("Page.captureScreenshot", captureBeyondViewport: true,
        clip: { x: 0, y: 0, width: width, height: page.evaluate_script("document.documentElement.scrollHeight"), scale: 1 })
      File.binwrite(Rails.root.join("tmp/shop-recommendation-#{width}.png"), Base64.decode64(capture["data"]))
      if width == 1440
        # Inspect the same fully populated test fixture without changing local data.
        html = page.html.sub("<head>", '<head><base href="http://localhost:3000">')
        File.write(Rails.root.join("tmp/shop-recommendation.html"), html)
      end
    end
  end

  [ 2, 3, 4, 6 ].each do |count|
    it "keeps #{count} recordings readable on desktop and phone" do
      (count - 1).times { |i| create_product(kind: :audio_process, name: "Audioproces #{i + 2}", position: i + 1) }
      [ 1440, 390 ].each do |width|
        visit "about:blank"
        viewport(width)
        visit products_path
        expect(page).to have_css(".shop-shelf article", count: count, visible: :all)
        expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
        if count >= 4
          expect(page).to have_css('[data-product-shelf-target="previous"][disabled]', visible: :all)
          overflows = page.evaluate_script("document.querySelector('.shop-shelf-rail').scrollWidth > document.querySelector('.shop-shelf-rail').clientWidth + 1")
          unless overflows
            expect(page).not_to have_css('[data-product-shelf-target="controls"]')
            next
          end
          expect(page).to have_css('[data-product-shelf-target="controls"]', visible: true)
          expect(page).to have_css('[data-product-shelf-target="previous"][disabled]')
          find('[data-product-shelf-target="next"]').click
          expect(page).to have_css('[data-product-shelf-target="previous"]:not([disabled])')
          track = find(".shop-shelf-rail")
          page.execute_script("const t = document.querySelector('.shop-shelf-rail'); t.scrollLeft = t.scrollWidth")
          expect(page).to have_css('[data-product-shelf-target="next"][disabled]')
          expect(page).to have_css(".shop-shelf-end")
          find('[data-product-shelf-target="previous"]').click
          expect(page).to have_css('[data-product-shelf-target="next"]:not([disabled])')
        else
          expect(page).not_to have_css('[data-product-shelf-target="controls"]')
          expect(page.evaluate_script(<<~JS)).to be(true)
            (() => {
              const cards = [...document.querySelectorAll('.shop-shelf article')].map(c => c.getBoundingClientRect());
              return innerWidth < 720 || cards.every(c => Math.abs(c.top - cards[0].top) < 1 && Math.abs(c.width - cards[0].width) < 1);
            })()
          JS
        end
      end
    end
  end

  it "keeps the shelf natively scrollable without its controller" do
    5.times { |i| create_product(kind: :audio_process, name: "Audio #{i}") }
    viewport(390)
    visit products_path
    expect(page).to have_css('[data-product-shelf-target="controls"]')
    page.execute_script("document.querySelector('[data-controller=product-shelf]').removeAttribute('data-controller')")
    track = find(".shop-shelf-rail")
    track.send_keys(:arrow_right)
    expect(page).to have_css(".shop-shelf-rail:focus")
    expect(page).to have_css(".shop-shelf-rail") { |element| element.evaluate_script("this.scrollLeft > 0") }
    expect(page.evaluate_script("document.querySelector('.shop-shelf-rail').scrollWidth > document.querySelector('.shop-shelf-rail').clientWidth")).to be(true)
  end
end
