require "rails_helper"

RSpec.describe "Front page resilience", type: :system do
  include Warden::Test::Helpers

  after do
    page.driver.browser.action.key_up(:shift).perform
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
    Warden.test_reset!
  end

  def viewport(width, height = 900)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: false)
  end

  def press_key(*keys)
    action = page.driver.browser.action
    if keys == [ [ :shift, :tab ] ]
      action.key_down(:shift).send_keys(:tab).key_up(:shift).perform
    else
      action.send_keys(*keys).perform
    end
  end

  [ nil, :en ].each do |locale|
    it "tabs through the mobile menu in both directions for #{locale || :pl}" do
      viewport(390)
      visit root_path(locale: locale)
      trigger = 'button[data-content-id="mobile-menu-content"]'
      find(trigger).send_keys(:enter)
      menu = "#mobile-menu-content"
      expect(page).to have_css("#{menu} a[href='#{audio_processes_path(locale: locale)}']:focus")

      press_key(:tab)
      expect(page).to have_css("#{menu} a[href='#{stories_path(locale: locale)}']:focus")
      press_key(:tab)
      expect(page).to have_css("#{menu} a[href='#{packages_path(locale: locale)}']:focus")
      press_key(:tab)
      expect(page).to have_css("#{menu} a[href='#{articles_path(locale: locale)}']:focus")
      press_key(:tab)
      expect(page).to have_css("#{menu} a[hreflang]:focus")
      press_key(:tab)
      expect(page).to have_css("#{menu} a[href='#{new_user_session_path(locale: locale)}']:focus")
      press_key([ :shift, :tab ])
      expect(page).to have_css("#{menu} a[hreflang]:focus")
      press_key([ :shift, :tab ])
      expect(page).to have_css("#{menu} a[href='#{articles_path(locale: locale)}']:focus")
      press_key([ :shift, :tab ])
      expect(page).to have_css("#{menu} a[href='#{packages_path(locale: locale)}']:focus")
      press_key(:escape)
      expect(page).to have_css("#{trigger}[aria-expanded='false']:focus")

      find(trigger).send_keys(:enter)
      expect(page).to have_css("#{menu} a:focus")
      6.times { press_key(:tab) }
      expect(page).to have_css("main a.offer-puzzle--audio:focus")
      expect(page).to have_css("#{trigger}[aria-expanded='false']")
    end
  end

  it "includes the sign-out button in desktop profile keyboard traversal" do
    user = User.create!(email: "keyboard@example.com", password: "password123")
    login_as user, scope: :user
    viewport(1440)
    visit root_path
    trigger = 'button[data-content-id="profile-content"]'
    find(trigger).send_keys(:enter)
    expect(page).to have_css("#profile-content a[href='#{dashboard_index_path}']:focus")
    press_key(:arrow_down)
    expect(page).to have_css("#profile-content button:focus")
    press_key([ :shift, :tab ])
    expect(page).to have_css("#profile-content a[href='#{dashboard_index_path}']:focus")
    press_key(:tab)
    expect(page).to have_css("#profile-content button:focus")
    press_key(:escape)
    expect(page).to have_css("#{trigger}[aria-expanded='false']:focus")
  end

  it "keeps a healthy portrait and replaces a failed one with the mascot" do
    ContentBlock.sync!
    ContentBlock.find_by!(key: "home.about.photo").image.attach(
      io: file_fixture("photo.png").open, filename: "photo.png", content_type: "image/png")
    viewport(1440)
    visit root_path
    image = '[data-image-fallback-target="image"]'
    fallback = '[data-image-fallback-target="fallback"]'
    header_rows = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('nav [data-navbar-target="menu"] > li')]
        .filter(item => item.getBoundingClientRect().width > 0)
        .map(item => { const rect = item.getBoundingClientRect(); return Math.round(rect.top + rect.height / 2); })
    JS
    expect(header_rows.uniq.size).to eq(1)
    expect(page).to have_css(image)
    expect(page).to have_css("#{image}:not([hidden])")
    expect(page).to have_css("#{fallback}[hidden]", visible: :all)
    expect(page).to have_css("#{image}[alt='Karola']")

    page.execute_script("document.querySelector('[data-image-fallback-target=image]').src = '/missing-home-portrait.png'")
    expect(page).to have_css("#{image}[hidden]", visible: :all)
    expect(page).to have_css("#{fallback}:not([hidden])")
    expect(page.evaluate_script("document.querySelector('[data-image-fallback-target=fallback]').naturalWidth")).to be > 0
    FileUtils.mkdir_p(Rails.root.join("tmp/home-hardening"))
    page.save_screenshot(Rails.root.join("tmp/home-hardening/portrait-fallback-desktop.png"))
  end

  it "shows the mascot when an image failure precedes controller connection" do
    visit root_path
    page.execute_script(<<~JS)
      const fixture = document.createElement('div');
      fixture.innerHTML = '<img data-image-fallback-target="image" src="/missing-cached-portrait.png"><span data-image-fallback-target="fallback" hidden>Fallback ready</span>';
      fixture.querySelector('img').addEventListener('error', () => {
        fixture.setAttribute('data-controller', 'image-fallback');
      });
      document.querySelector('main').appendChild(fixture);
    JS
    expect(page).to have_text("Fallback ready")
  end

  it "wraps long CMS copy at 320px and at a 200% text scale" do
    ContentBlock.sync!
    ContentBlock.find_by!(key: "home.hero.title").update!(value_pl: "Sen#{'ą' * 100} 🌙")
    ContentBlock.find_by!(key: "home.choices.audio").update!(value_pl: "https://example.com/#{'abc' * 100}")
    viewport(320)
    visit root_path
    expect(page).to have_css("h1", text: "Sen")
    [ 16, 32 ].each do |size|
      page.execute_script("document.documentElement.style.fontSize = '#{size}px'")
      dimensions = page.evaluate_script(<<~JS)
        ({ viewport: window.innerWidth, document: document.documentElement.scrollWidth,
           overflowing: [...document.querySelectorAll('main h1, main .offer-puzzle')].some(element => element.scrollWidth > element.clientWidth + 1),
           outside: [...document.querySelectorAll('nav *, footer *')].filter(element => {
             const rect = element.getBoundingClientRect();
             return element.getClientRects().length && (rect.left < -1 || rect.right > window.innerWidth + 1);
           }).map(element => ({ tag: element.tagName, class: element.className, width: element.getBoundingClientRect().width })) })
      JS
      expect(dimensions["document"]).to be <= dimensions["viewport"], dimensions.inspect
      expect(dimensions["overflowing"]).to be(false)
    end
  end

  it "opens and closes navigation immediately with reduced motion" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia",
      features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    viewport(390)
    visit root_path
    trigger = 'button[data-content-id="mobile-menu-content"]'
    find(trigger).send_keys(:enter)
    expect(page).to have_css('#mobile-menu-content a:focus')
    expect(page).to have_css('[data-navbar-target="viewport"][data-state="open"]')
    motion = page.evaluate_script(<<~JS)
      (() => {
        const viewport = document.querySelector('[data-navbar-target="viewport"]');
        const style = getComputedStyle(viewport);
        return { duration: style.transitionDuration, scale: style.scale };
      })()
    JS
    expect(motion).to eq("duration" => "0s", "scale" => "1")
    press_key(:escape)
    expect(page).to have_css('[data-navbar-target="viewport"][data-state="closed"]', visible: :all)
    expect(page).to have_css("#{trigger}:focus")
  end

  it "offers a localized keyboard skip link to the main content" do
    visit root_path(locale: :en)
    find('a[href="#main-content"]', visible: :all).send_keys(:enter)
    expect(page).to have_css("main#main-content:focus")
    expect(page).to have_link("Skip to content", href: "#main-content", visible: :all)
  end
end
