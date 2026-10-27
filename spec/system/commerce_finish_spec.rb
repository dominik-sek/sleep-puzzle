require "rails_helper"

RSpec.describe "Commerce finishing pass", type: :system do
  include Warden::Test::Helpers

  before do
    ContentBlock.sync!
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_123"), paddle_price(id: "pri_456") ])
    allow(GoogleCalendarService).to receive(:call).and_return(instance_double(GoogleCalendarService, busy: []))
    @user = User.create!(email: "finish@example.com", password: "password123", admin: true)
    login_as @user, scope: :user
  end

  after { Warden.test_reset! }

  it "announces every changed payment outcome through the same persistent live node" do
    product = create_product
    order = @user.orders.create!(status: :pending, order_items: [ OrderItem.new(product: product) ])
    booking = Booking.create!(user: @user, package: create_package, name: "Marta", email: @user.email,
                             starts_at: 25.days.from_now, status: :pending)
    { order: [ order, order_path(order), "orders/status", :paid ], booking: [ booking, booking_path(booking), "bookings/status", :confirmed ] }.each do |kind, (record, path, partial, success)|
      visit path
      expect(page).to have_css('[data-controller="payment-status"]')
      announcement = find('[data-payment-status-target="announcement"]', visible: :all)
      expect(announcement.text(:all)).to be_empty
      page.execute_script("window.paymentAnnouncementBefore = document.querySelector('[data-payment-status-target=announcement]')")
      [ success, :payment_failed ].each do |status|
        record.status = status
        html = ApplicationController.render(partial: partial, locals: { kind => record })
        page.execute_script("Turbo.renderStreamMessage(arguments[0])", %(<turbo-stream action="replace" target="#{kind}_status"><template>#{html}</template></turbo-stream>))
        expected = Nokogiri::HTML.fragment(html).at_css("h1").text.strip
        expect(page).to have_css('[data-payment-status-target="announcement"]', text: expected, visible: :all)
        expect(page.evaluate_script("window.paymentAnnouncementBefore === document.querySelector('[data-payment-status-target=announcement]')")).to be(true)
        expect(announcement[:"aria-live"]).to eq("polite")
        expect(announcement.text(:all)).not_to include(product.name)
      end
    end
  end

  it "preserves commerce identity and layout on mobile with enlarged text" do
    product = create_product(name: "Bajka na spokojny wieczór i dobranoc dla małego odkrywcy")
    package = create_package(name: "Wsparcie dla całej rodziny")
    booking = Booking.create!(user: @user, package: package, name: "Marta", email: @user.email,
                             starts_at: 25.days.from_now, status: :confirmed)
    page.driver.browser.manage.window.resize_to(390, 844)
    visit catalogue_product_path(product)
    find("form[action='#{cart_items_path}'] button").click
    expect(page).to have_css("main form[action$='/cart_items/#{product.id}']")
    [ cart_path, booking_path(booking), dashboard_index_path, new_admin_product_path, new_admin_article_path ].each do |path|
      visit path
      page.execute_script("document.documentElement.style.fontSize='200%'")
      expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
      expect(page.evaluate_script("document.querySelector('main').scrollWidth <= document.querySelector('main').clientWidth + 1")).to be(true)
      if path == cart_path
        link = find("main a", text: product.name)
        expect(link[:class]).not_to include("truncate")
        expect(link.evaluate_script("this.scrollWidth <= this.clientWidth + 1")).to be(true)
        page.save_screenshot(Rails.root.join("tmp/polish-cart-mobile-200.png"))
      end
    end
    page.driver.browser.manage.window.resize_to(1280, 900)
    visit cart_path
    expect(page).to have_link(product.name)
    page.save_screenshot(Rails.root.join("tmp/polish-cart-desktop.png"))
  end

  it "keeps editor actions touch sized and the enlarged calendar within its container" do
    create_package
    page.driver.browser.manage.window.resize_to(390, 844)
    visit new_admin_article_path
    expect(page).to have_css("trix-toolbar .trix-button")
    sizes = page.evaluate_script("Array.from(document.querySelectorAll('trix-toolbar .trix-button')).filter(e=>e.getClientRects().length).map(e=>{const r=e.getBoundingClientRect();return Math.min(r.width,r.height)})")
    expect(sizes).to all(be >= 44)
    editor = find("trix-editor", match: :first)
    editor.click
    editor.send_keys("Tekst do edycji")
    editor.send_keys([ :control, "a" ])
    find('trix-toolbar [data-trix-action="link"]', match: :first).click
    expect(page).to have_css('trix-toolbar input[type="url"]')
    expect(page.evaluate_script("getComputedStyle(document.querySelector('trix-toolbar .trix-dialog')).boxShadow")).to eq("none")
    expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
    page.save_screenshot(Rails.root.join("tmp/polish-editor-mobile.png"))
    visit bookings_path
    expect(page).to have_css("calendar-month")
    page.execute_script("document.documentElement.style.fontSize='200%'")
    expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
  end
end
