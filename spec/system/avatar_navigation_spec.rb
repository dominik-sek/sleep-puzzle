require "rails_helper"

RSpec.describe "Profile avatar navigation", type: :system do
  include Warden::Test::Helpers

  after { Warden.test_reset! }

  it "keeps the loaded avatar element during a Turbo page visit" do
    avatar = "data:image/svg+xml;base64,#{Base64.strict_encode64('<svg xmlns="http://www.w3.org/2000/svg" width="2" height="2"/>')}"
    user = User.create!(email: "avatar@example.com", password: "password123",
                        first_name: "Karola", avatar_url: avatar)
    login_as user, scope: :user
    page.driver.browser.manage.window.resize_to(1280, 900)

    visit root_path
    expect(page).to have_css('[data-controller="avatar"] img')
    expect(page.evaluate_script('document.querySelector("[data-controller=avatar] img").naturalWidth')).to be > 0
    page.execute_script('window.avatarBeforeVisit = document.querySelector("[data-controller=avatar]")')

    find("a.offer-puzzle--audio").click

    expect(page).to have_current_path(audio_process_path)
    expect(page.evaluate_script('window.avatarBeforeVisit === document.querySelector("[data-controller=avatar]")')).to be(true)
  end
end
