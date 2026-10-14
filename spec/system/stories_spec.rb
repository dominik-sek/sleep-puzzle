require "rails_helper"

RSpec.describe "Story samples and collection navigation", type: :system do
  before do
    ContentBlock.sync!
    with_bunny_cdn
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456") ])
    @story = create_product(name: "Bajka o sowie", description: "Opowieść do wspólnego słuchania.",
      length_minutes: 12, preview_cdn_path: "/previews/owl.wav")
    @other = create_product(name: "Bajka o lesie", preview_cdn_path: "/previews/forest.wav")

    # A real 30-second PCM WAV served locally, without ffmpeg or external CDN requests.
    period = Array.new(8000) { |i| (128 + 20 * Math.sin(2 * Math::PI * 440 * i / 8000)).round }.pack("C*")
    samples = period * 30
    wave = "RIFF" + [ 36 + samples.bytesize ].pack("V") + "WAVEfmt " +
      [ 16, 1, 1, 8000, 8000, 1, 8 ].pack("VvvVVvv") + "data" + [ samples.bytesize ].pack("V") + samples
    @blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(wave), filename: "sample.wav", content_type: "audio/wav")
    [ @story, @other ].each do |story|
      allow(BunnySignedUrlService).to receive(:call).with(story.preview_cdn_path, expires_in: ProductsController::PREVIEW_TTL)
        .and_return(Rails.application.routes.url_helpers.rails_storage_proxy_path(@blob, only_path: true))
    end
  end

  after do
    @blob&.purge
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  def player(product)
    find("audio[src='#{preview_product_path(product)}']")
  end

  def wait_for_playback(product)
    Selenium::WebDriver::Wait.new(timeout: 5).until do
      page.evaluate_script("document.querySelector('audio[src=\"#{preview_product_path(product)}\"]').currentTime > 0")
    end
  end

  it "loads no media until play and pauses the previous sample without resetting it or moving focus" do
    visit stories_path
    expect(page.evaluate_script("performance.getEntriesByType('resource').some(r => r.name.includes('/preview') || r.name.includes('sample.wav') || r.name.includes('b-cdn.net'))")).to be(false)
    player(@story).send_keys(:space)
    wait_for_playback(@story)
    player(@other).send_keys(:space)
    wait_for_playback(@other)

    expect(page.evaluate_script("document.querySelectorAll('audio')[0].paused")).to be(true)
    expect(page.evaluate_script("document.querySelectorAll('audio')[0].currentTime")).to be > 0
    expect(page.evaluate_script("document.activeElement === document.querySelectorAll('audio')[1]")).to be(true)
    expect(page).not_to have_text("Nie udało się odtworzyć nagrania")
  end

  it "preserves the player and playback during keyboard add/remove actions and keeps commerce focus" do
    visit stories_path
    player(@story).send_keys(:space)
    wait_for_playback(@story)
    page.execute_script("window.storyPlayer = document.querySelector('audio'); window.storyPosition = window.storyPlayer.currentTime")
    region = "#cart_toggle_product_#{@story.id}"
    find("#{region} button[aria-label^='Dodaj']").send_keys(:enter)
    expect(page).to have_css("#{region} button[aria-label^='Usuń']:focus")
    expect(page).to have_css("#{region} [aria-live='polite']", text: "Dodano")
    expect(page.evaluate_script("window.storyPlayer === document.querySelector('audio') && !window.storyPlayer.paused && window.storyPlayer.currentTime >= window.storyPosition")).to be(true)

    find("#{region} button[aria-label^='Usuń']").send_keys(:enter)
    expect(page).to have_css("#{region} button[aria-label^='Dodaj']:focus")
    expect(page.evaluate_script("window.storyPlayer === document.querySelector('audio') && !window.storyPlayer.paused && window.storyPlayer.currentTime >= window.storyPosition")).to be(true)
  end

  it "stops on navigation and does not resume after returning through Turbo history" do
    visit stories_path
    player(@story).send_keys(:space)
    wait_for_playback(@story)
    page.execute_script("window.departingPlayer = document.querySelector('audio')")
    within("main") { click_link @story.name }
    expect(page).to have_current_path(product_path(@story))
    expect(page.evaluate_script("window.departingPlayer.paused")).to be(true)
    page.go_back
    expect(page).to have_current_path(stories_path)
    expect(page.evaluate_script("Array.from(document.querySelectorAll('audio')).every(p => p.paused)")).to be(true)
  end

  it "recovers a failed sample locally without blocking details or cart actions" do
    allow(BunnySignedUrlService).to receive(:call).with(@story.preview_cdn_path, expires_in: ProductsController::PREVIEW_TTL)
      .and_return("/products/0/preview")
    visit stories_path
    player(@story).send_keys(:space)
    card = player(@story).ancestor("article")
    expect(card).to have_css("[role='status']", text: "Nie udało się odtworzyć nagrania")
    expect(player(@other).ancestor("article")).not_to have_text("Nie udało się odtworzyć nagrania")
    expect(card).to have_link("Zobacz szczegóły")
    expect(card).to have_button("Dodaj do koszyka")

    allow(BunnySignedUrlService).to receive(:call).with(@story.preview_cdn_path, expires_in: ProductsController::PREVIEW_TTL)
      .and_return(Rails.application.routes.url_helpers.rails_storage_proxy_path(@blob, only_path: true))
    card.find("button", text: "Spróbuj odtworzyć ponownie").send_keys(:enter)
    wait_for_playback(@story)
    expect(card).not_to have_text("Nie udało się odtworzyć nagrania")
  end

  [ 320, 390, 1440 ].each do |width|
    it "keeps native samples, long names and enlarged text within #{width}px" do
      @story.assign_translation(:name, :pl, "Bardzodługanazwa" * 12)
      @story.save!
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
        width: width, height: 844, deviceScaleFactor: 1, mobile: false)
      visit stories_path
      page.execute_script("document.documentElement.style.fontSize = '200%'")
      expect(page).to have_css("main h2", text: @story.name)
      expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
      expect(player(@story).native.rect.width).to be <= width
      expect(find("#cart_toggle_product_#{@story.id} button").native.rect.height).to be >= 44
    end
  end

  it "keeps the same collection and product when switching language" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: 1440, height: 900, deviceScaleFactor: 1, mobile: false)
    visit stories_path
    find('button[aria-controls="locale-content"]').send_keys(:enter)
    within("#locale-content") { click_link "English" }
    expect(page).to have_current_path(stories_path(locale: :en))
    within("main") { click_link @story.name }
    expect(page).to have_current_path(product_path(@story, locale: :en))
    find("main nav a", text: "Back to audio stories").send_keys(:enter)
    expect(page).to have_current_path(stories_path(locale: :en))
  end
end

RSpec.describe "Stories shop return target", type: :system do
  before do
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456") ])
  end

  after { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  [ nil, :en ].each do |locale|
    [ :empty, :populated ].each do |state|
      it "keeps the #{locale || :pl} shop link at least 44 by 44 pixels in the #{state} collection" do
        create_product if state == :populated

        [ 320, 390, 1440 ].each do |width|
          page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
            width: width, height: 844, deviceScaleFactor: 1, mobile: false)
          visit stories_path(locale: locale)

          link = find("main a[href='#{products_path(locale: locale)}']", text: locale ? "Shop" : "Sklep")
          rect = link.native.rect
          expect(rect.width).to be >= 44
          expect(rect.height).to be >= 44
          expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
        end
      end
    end
  end
end
