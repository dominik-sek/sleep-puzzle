require "rails_helper"

RSpec.describe "Privacy policy", type: :request do
  it "is public in Polish and describes both Google data flows" do
    get privacy_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Polityka prywatności")
    expect(response.body).to include("Logowanie przez Google")
    expect(response.body).to include("Kalendarz Google administratora")
  end

  it "is available in English" do
    get privacy_path(locale: :en)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Privacy policy")
    expect(response.body).to include("Administrator&#39;s Google Calendar")
  end

  it "is linked near Google sign-in" do
    get new_user_session_path

    expect(response.body).to include(%(href="#{privacy_path}"))
  end
end
