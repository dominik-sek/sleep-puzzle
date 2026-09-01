require 'rails_helper'

RSpec.describe "Integrations::GoogleCalendar", type: :request do
  let(:customer) { User.create!(email: "customer@example.com", password: "password123") }
  let(:admin) { User.create!(email: "owner@example.com", password: "password123", admin: true) }
  let(:second_admin) { User.create!(email: "dominik@example.com", password: "password123", admin: true) }

  it "sends a signed-out visitor to sign in" do
    get integrations_google_calendar_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "redirects a signed-in non-admin away" do
    sign_in customer

    get integrations_google_calendar_path

    expect(response).to redirect_to(root_path)
  end

  it "lets an admin in" do
    sign_in admin

    get integrations_google_calendar_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Nie połączono")
  end

  # It is reached from the panel's sidebar, so it renders inside the panel rather
  # than dropping the visitor onto the public navbar and footer mid-task.
  it "renders in the admin layout, with the sidebar" do
    sign_in admin

    get integrations_google_calendar_path

    expect(response.body).to include("Rezerwacje")
    expect(response.body).to include(admin_root_path)
    expect(response.body).not_to include(new_user_session_path)
  end

  # The point of moving off OWNER_EMAIL: access is no longer one address, so a
  # second promoted account reaches the same screen without a redeploy.
  it "lets a second admin in" do
    sign_in second_admin

    get integrations_google_calendar_path

    expect(response).to have_http_status(:ok)
  end

  # OWNER_EMAIL still names the notification inbox, and that must no longer be
  # what grants access - matching it while not being an admin gets you nothing.
  it "refuses someone who merely matches OWNER_EMAIL" do
    stub_const("ENV", ENV.to_h.merge("OWNER_EMAIL" => customer.email))
    sign_in customer

    get integrations_google_calendar_path

    expect(response).to redirect_to(root_path)
  end

  it "shows the connected state when the integration exists" do
    Integration.create!(service_name: Integration::GOOGLE_CALENDAR)
    sign_in admin

    get integrations_google_calendar_path

    expect(response.body).to include("Połączono")
  end

  describe "DELETE /integrations/google_calendar" do
    let(:authorizer) { instance_double(Google::Auth::WebUserAuthorizer) }

    before do
      Integration.create!(service_name: Integration::GOOGLE_CALENDAR)
      allow(AuthorizeCalendarService).to receive(:call).and_return(authorizer)
      sign_in admin
    end

    it "revokes the grant and drops the row" do
      expect(authorizer).to receive(:revoke_authorization).with(Integration::GOOGLE_CALENDAR)

      delete integrations_google_calendar_path

      expect(response).to redirect_to(integrations_google_calendar_path)
      expect(Integration.find_by(service_name: Integration::GOOGLE_CALENDAR)).to be_nil
    end

    # Google answers 400 to a revoke of a token it has already expired, and the
    # gem raises before it deletes anything. Unrescued this 500'd and left the row
    # behind, so the panel kept claiming "Połączono" with no way back.
    it "still disconnects when Google refuses the revoke" do
      allow(authorizer).to receive(:revoke_authorization)
        .and_raise(Google::Auth::AuthorizationError.new("Unexpected error code 400"))

      delete integrations_google_calendar_path

      expect(response).to redirect_to(integrations_google_calendar_path)
      expect(Integration.find_by(service_name: Integration::GOOGLE_CALENDAR)).to be_nil
    end

    it "leaves the panel showing the disconnected state afterwards" do
      allow(authorizer).to receive(:revoke_authorization)
        .and_raise(Google::Auth::AuthorizationError.new("Unexpected error code 400"))

      delete integrations_google_calendar_path
      follow_redirect!

      expect(response.body).to include("Nie połączono")
    end
  end
end
