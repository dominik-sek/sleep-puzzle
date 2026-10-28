require "rails_helper"

RSpec.describe "Agent authentication discovery", type: :request do
  [ nil, "text/html", "text/markdown", "application/json" ].each do |accept|
    it "serves root auth.md as Markdown for Accept #{accept.inspect}" do
      get "/auth.md", headers: accept ? { "Accept" => accept } : {}

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("text/markdown; charset=utf-8")
      expect(response.body).to start_with("# Sleep Puzzle auth.md\n")
      expect(response.body).to include("## Agent audience", "## Registration methods", "## Credential use")
      expect(response.body).to include(new_user_registration_path, new_user_session_path,
                                       user_google_oauth2_omniauth_authorize_path, destroy_user_session_path)
      expect(response.body).not_to include("<!DOCTYPE html>")
    end
  end

  it "allows discovery by agents with an older browser user agent" do
    get "/auth.md", headers: { "User-Agent" => "Mozilla/5.0 Version/12.0 Safari/605.1.15" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
  end

  it "answers HEAD without registering an account or sending email" do
    expect {
      head "/auth.md"
    }.not_to change(User, :count)

    expect(ActionMailer::Base.deliveries).to be_empty
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to be_empty
  end
end
