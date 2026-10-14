require "rails_helper"

RSpec.describe "Product detail reading order", type: :system do
  before do
    ContentBlock.sync!
    with_bunny_cdn
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456") ])
    @program = create_product(kind: :audio_process, name: "Proces dla rodziców", description: "Wsparcie we własnym tempie.")
    @story = create_product(name: "Bajka na spokojny wieczór", description: "Opowieść do słuchania.")
    @trailer = create_product(kind: :audio_process, name: "Proces z wprowadzeniem", trailer_cdn_path: "/trailers/intro.mp4")
  end

  after { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  [ 320, 390 ].each do |width|
    %i[program story trailer].each do |variant|
      it "puts the #{variant} identity and purchase before media at #{width}px" do
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
          width: width, height: 844, deviceScaleFactor: 1, mobile: false)
        product = instance_variable_get("@#{variant}")
        visit product_path(product)

        expect(page).to have_css(".product-identity h1", text: product.name)
        expect(page.evaluate_script("document.querySelector('.product-media').getBoundingClientRect().top >= document.querySelector('.product-identity').getBoundingClientRect().bottom - 1")).to be(true)
        expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
        back = find("main a", text: product.audio_process? ? "Wróć do audioprocesów" : "Wróć do bajek audio")
        expect(back.native.rect.height).to be >= 44
      end
    end
  end

  [ 844, 1440 ].each do |width|
    it "keeps supporting media left of the product on a wide viewport at #{width}px" do
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
        width: width, height: 700, deviceScaleFactor: 1, mobile: false)
      visit product_path(@program)

      expect(page.evaluate_script("document.querySelector('.product-media').getBoundingClientRect().right <= document.querySelector('.product-identity').getBoundingClientRect().left")).to be(true)
      expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
    end
  end

  it "keeps long names and in-cart actions readable with doubled text on a narrow phone" do
    @program.assign_translation(:name, :pl, "Bardzodługanazwa" * 10)
    @program.save!
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: 320, height: 844, deviceScaleFactor: 1, mobile: false)
    visit product_path(@program)
    find('button[aria-label^="Dodaj do koszyka"]').click
    expect(page).to have_link("Przejdź do koszyka")
    page.execute_script("document.documentElement.style.fontSize = '200%'")

    overflow = page.evaluate_script("Array.from(document.querySelectorAll('main *')).filter(e => e.clientWidth && e.scrollWidth > e.clientWidth + 1).slice(-8).map(e => ({tag: e.tagName, classes: e.className, width: e.clientWidth, scrollWidth: e.scrollWidth}))")
    expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true), overflow.inspect
    expect(page).to have_link("Przejdź do koszyka")
  end

  it "supports keyboard navigation back to the localized shop" do
    visit product_path(@story, locale: :en)
    find("main nav a", text: "Shop").send_keys(:enter)

    expect(page).to have_current_path(products_path(locale: :en))
  end
end
