require "rails_helper"

RSpec.describe "Refunds on mobile", type: :system do
  include Warden::Test::Helpers
  let(:user) { User.create!(email: "mobile-refund@example.com", password: "password123") }

  before do
    login_as user, scope: :user
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: false)
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456"), paddle_price(id: "pri_123") ])
  end

  after do
    Warden.test_reset!
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  it "keeps policy and the unchecked audio consent readable without horizontal scrolling" do
    [ refunds_path, refunds_path(locale: :en) ].each do |path|
      visit path
      expect(page).to have_link(href: "https://paddle.net")
      expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 390
    end
    product = create_product
    visit product_path(product)
    find("form[action='#{cart_items_path}'] button").click
    expect(page).to have_link(href: cart_path)
    visit cart_path
    expect(page).to have_unchecked_field("digital_content_consent")
    expect(find_field("digital_content_consent")[:required]).to eq("true")
    expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 390
    page.save_screenshot(Rails.root.join("tmp/refunds/mobile-cart.png"))
  end

  it "requires consent only for an early appointment" do
    ConsultationSetting.current.update!(local_availability: true)
    package = create_package
    slots = SlotComparatorService.call.map(&:begin)
    [ slots.find { |start| start < 14.days.from_now }, slots.find { |start| start > 14.days.from_now } ].each_with_index do |start, index|
      visit bookings_path(date: start.to_date.to_s, hour: start.strftime("%H:%M"), package_id: package.id)
      expect(page).to have_unchecked_field("booking_early_service_consent")
      expect(page.evaluate_script("document.querySelector('[data-early-service-cutoff]').required")).to eq(index.zero?)
      expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 390
    end
    page.save_screenshot(Rails.root.join("tmp/refunds/mobile-booking.png"))
  end

  it "records playing rather than buffering or errors, once for the purchase" do
    product = create_product
    item = user.orders.create!(status: :paid, order_items: [ OrderItem.new(product: product) ]).order_items.sole
    allow(BunnySignedUrlService).to receive(:configured?).and_return(true)
    allow(BunnySignedUrlService).to receive(:call).and_return("https://audio.example.com/audio.mp3")
    visit dashboard_index_path
    expect(page).to have_css('audio[data-controller="playback"]')
    expect(item.reload.first_stream_issued_at).to be_nil
    page.execute_script(<<~JS)
      window.originalFetch = window.fetch;
      window.fetch = async (...args) => {
        const response = await window.originalFetch(...args);
        if (String(args[0]).includes('/playback')) document.body.dataset.playbackSaved = response.status;
        return response;
      };
      const audio = document.querySelector('audio[data-controller="playback"]');
      audio.dispatchEvent(new Event('waiting'));
      audio.dispatchEvent(new Event('error'));
      window.fetch(audio.src, { redirect: 'manual' }).then(() => document.body.dataset.streamIssued = 'true');
    JS
    expect(page).to have_css('body[data-stream-issued="true"]')
    expect(item.reload.first_stream_issued_at).to be_present
    expect(item.first_played_at).to be_nil
    # Use real browser playback of a local silent WAV, without contacting CDN.
    pcm = "\0" * 16_000
    wav = "RIFF" + [ 36 + pcm.bytesize ].pack("V") + "WAVEfmt " + [ 16, 1, 1, 8000, 16000, 2, 16 ].pack("VvvVVvv") + "data" + [ pcm.bytesize ].pack("V") + pcm
    page.execute_script(<<~JS, Base64.strict_encode64(wav))
      const audio = document.querySelector('audio[data-controller="playback"]');
      audio.src = 'data:audio/wav;base64,' + arguments[0];
      const play = document.createElement('button');
      play.textContent = 'Test playback';
      play.onclick = () => audio.play();
      document.body.append(play);
    JS
    click_button "Test playback"
    expect(page).to have_css('body[data-playback-saved="204"]')
    first = item.reload.first_played_at
    expect(first).to be_present
    page.execute_script("document.querySelector('audio[data-controller=playback]').dispatchEvent(new Event('playing'))")
    expect(item.reload.first_played_at).to eq(first)
  end
end
