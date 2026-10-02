require "rails_helper"

RSpec.describe "Audio chapter playlist", type: :system do
  include Warden::Test::Helpers

  after { Warden.test_reset! }

  it "selects a chapter and advances to the next one on ended, also at mobile width" do
    product = create_product(kind: :audio_process)
    second = product.audio_chapters.create!(position: 1, cdn_path: "/audioprocesy/second.mp3",
                                            duration_seconds: 37, translations: { "title" => { "pl" => "Drugi etap" } })
    user = User.create!(email: "listener@example.com", password: "password123")
    user.orders.create!(status: :paid, order_items: [ OrderItem.new(product: product) ])
    with_bunny_cdn
    login_as user, scope: :user
    page.driver.browser.manage.window.resize_to(390, 844)

    visit dashboard_index_path
    expect(page).to have_css('[data-controller="chapter-playlist"]')
    expect(page).to have_css('[data-chapter-playlist-target="chapter"][aria-pressed="true"]', count: 1)
    expect(page).to have_css("audio[src*='chapters']", visible: :all)

    page.execute_script('document.querySelector("[data-chapter-playlist-target=player]").dispatchEvent(new Event("ended", { bubbles: true }))')
    expect(page).to have_css("[data-chapter-playlist-target=chapter][data-index='1'][aria-pressed='true']")
    expect(page).to have_css("audio[src*='#{second.id}']", visible: :all)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
  end
end
