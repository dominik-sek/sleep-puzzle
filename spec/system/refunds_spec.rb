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
      if index == 1
        expect(page).to have_text("nie musisz udzielać dodatkowej zgody")
        expect(page).not_to have_field("booking_early_service_consent")
        find("[data-early-consent-details] summary").click
      end
      expect(page).to have_unchecked_field("booking_early_service_consent")
      expect(page.evaluate_script("document.querySelector('[data-early-service-cutoff]').required")).to eq(index.zero?)
      if index.zero?
        fill_in "booking_name", with: "Marta"
        find("#booking_form button[type=submit]").click
        expect(page).to have_unchecked_field("booking_early_service_consent")
        expect(Booking.count).to eq(0)
      end
      expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 390
    end
    page.save_screenshot(Rails.root.join("tmp/refunds/mobile-booking.png"))
  end

  it "opens the policy from the booking form as a complete page" do
    ConsultationSetting.current.update!(local_availability: true)
    package = create_package
    start = SlotComparatorService.call.map(&:begin).first
    visit bookings_path(date: start.to_date.to_s, hour: start.strftime("%H:%M"), package_id: package.id)
    within "#booking_form" do
      click_link "Zwroty i odwołania"
    end
    expect(page).to have_current_path(refunds_path)
    expect(page).to have_css("h1", text: "Zwroty i odwoływanie konsultacji")
    expect(page).not_to have_text("Content missing")
  end

  it "releases the slot when the checkout is closed without payment, ignoring an old transaction with the same booking id" do
    ConsultationSetting.current.update!(local_availability: true)
    package = create_package
    start = SlotComparatorService.call.map(&:begin).find { |time| time > 14.days.from_now }
    Pay::PaddleBilling::Customer.create!(owner: user, processor: :paddle_billing, processor_id: "ctm_mobile", default: true)
    allow_any_instance_of(Pay::PaddleBilling::Customer).to receive(:api_record).and_return(Paddle::Customer.new(id: "ctm_mobile"))
    allow(BookingCalendarService).to receive(:call).and_return(instance_double(BookingCalendarService, create: true, release: true))
    allow(Paddle::Transaction).to receive(:list) do
      booking = Booking.sole
      [
        Paddle::Transaction.new(id: "txn_draft", status: "draft", payments: [], created_at: booking.created_at.iso8601(6),
          custom_data: { booking_id: booking.id.to_s, booking_token: booking.token }),
        Paddle::Transaction.new(id: "txn_old", status: "completed", payments: [ { status: "captured" } ], created_at: 1.day.ago.iso8601,
          custom_data: { booking_id: booking.id.to_s })
      ]
    end
    visit bookings_path(date: start.to_date.to_s, hour: start.strftime("%H:%M"), package_id: package.id)
    # A local SDK double exercises the real Stimulus callback, DELETE request,
    # Paddle verification and Turbo response, without opening an external checkout.
    page.execute_script(<<~JS)
      window.Paddle = {
        Environment: { set() {} },
        Initialize({ eventCallback }) { this.callback = eventCallback; },
        Checkout: { open() {
          const cancel = document.createElement('button');
          cancel.textContent = 'Close test checkout';
          cancel.onclick = () => {
            Paddle.callback({ name: 'checkout.closed' });
            Paddle.callback({ name: 'checkout.closed' });
            cancel.remove();
          };
          document.body.append(cancel);
        } }
      };
      const append = document.head.appendChild.bind(document.head);
      document.head.appendChild = (node) => {
        if (node.src === 'https://cdn.paddle.com/paddle/v2/paddle.js') {
          queueMicrotask(() => node.dispatchEvent(new Event('load')));
          return node;
        }
        return append(node);
      };
    JS
    fill_in "booking_name", with: "Marta"
    find("#booking_form button[type=submit]").click
    expect(page).to have_button("Close test checkout")
    expect(Booking.sole).to be_pending
    click_button "Close test checkout"
    expect(page).to have_css("#booking_notice", text: "Nie pobraliśmy żadnej opłaty")
    expect(page).not_to have_text("Płatność została zaksięgowana")
    expect(Booking.count).to eq(0)
    expect(find("[data-date='#{start.to_date}'] [data-hour='#{start.strftime('%H:%M')}']", visible: false)).not_to be_disabled
    page.save_screenshot(Rails.root.join("tmp/refunds/mobile-abandoned-checkout.png"))
  end

  it "lets the buyer open an editable refund request from a purchased recording" do
    product = create_product
    item = user.orders.create!(status: :paid, paddle_transaction_id: "txn_mobile", order_items: [ OrderItem.new(product: product) ]).order_items.sole
    visit dashboard_index_path
    within "#product_#{product.id}" do
      click_link "Zgłoś zwrot"
    end
    expect(page).to have_css("h1", text: "Zgłoś zwrot")
    expect(page).to have_field("contact_message_body", with: /txn_mobile/)
    expect(page).to have_current_path(contact_path(order_item_id: item.id))
    expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 390
    page.save_screenshot(Rails.root.join("tmp/refunds/mobile-refund-request.png"))
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
