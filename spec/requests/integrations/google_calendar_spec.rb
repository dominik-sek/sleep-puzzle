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
    Integration.create!(service_name: Integration::GOOGLE_CALENDAR, calendar_id: "abc@group.calendar.google.com")
    sign_in admin

    get integrations_google_calendar_path

    expect(response.body).to include("Połączono")
  end

  describe "the calendar picker" do
    let(:calendar) { instance_double(GoogleCalendarService) }

    def entry(id:, summary:, primary: false, summary_override: nil)
      Google::Apis::CalendarV3::CalendarListEntry.new(
        id: id, summary: summary, primary: primary, summary_override: summary_override
      )
    end

    before { sign_in admin }

    it "lists the writable calendars of the connected account" do
      Integration.create!(service_name: Integration::GOOGLE_CALENDAR)
      allow(GoogleCalendarService).to receive(:call).and_return(calendar)
      allow(calendar).to receive(:writable_calendars).and_return([
        entry(id: "primary@example.com", summary: "Anna", primary: true),
        entry(id: "work@group.calendar.google.com", summary: "Konsultacje")
      ])

      get integrations_google_calendar_path

      expect(response.body).to include("work@group.calendar.google.com", "Konsultacje")
    end

    # A connected account with nothing picked is a half-finished setup, and the
    # badge has to say so rather than claim everything is wired up.
    it "asks for a calendar when the account is connected but none is chosen" do
      stub_const("ENV", ENV.to_h.except("GOOGLE_CALENDAR_ID"))
      Integration.create!(service_name: Integration::GOOGLE_CALENDAR)
      allow(GoogleCalendarService).to receive(:call).and_return(calendar)
      allow(calendar).to receive(:writable_calendars).and_return([])

      get integrations_google_calendar_path

      expect(response.body).to include("Wybierz kalendarz")
      expect(response.body).not_to include("Połączono")
    end

    # Listing runs against Google on every render, so a bad day there must leave
    # the rest of the screen - including the disconnect button - usable.
    it "still renders when the calendar list cannot be fetched" do
      Integration.create!(service_name: Integration::GOOGLE_CALENDAR)
      allow(GoogleCalendarService).to receive(:call)
        .and_raise(GoogleCalendarService::NotConnected, "no Google Calendar is connected")

      get integrations_google_calendar_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Nie udało się pobrać listy kalendarzy")
    end

    it "does not call Google before the account is connected" do
      expect(GoogleCalendarService).not_to receive(:call)

      get integrations_google_calendar_path

      expect(response.body).to include("Nie połączono")
    end
  end

  describe "PATCH /integrations/google_calendar" do
    before { sign_in admin }

    it "stores the chosen calendar" do
      integration = Integration.create!(service_name: Integration::GOOGLE_CALENDAR)

      patch integrations_google_calendar_path, params: { integration: { calendar_id: "work@group.calendar.google.com" } }

      expect(response).to redirect_to(integrations_google_calendar_path)
      expect(integration.reload.calendar_id).to eq("work@group.calendar.google.com")
    end

    # The select carries a blank option, so submitting it must not wipe a working
    # calendar out from under the bookings.
    it "keeps the current calendar when the blank option is submitted" do
      integration = Integration.create!(service_name: Integration::GOOGLE_CALENDAR, calendar_id: "work@example.com")

      patch integrations_google_calendar_path, params: { integration: { calendar_id: "" } }

      expect(integration.reload.calendar_id).to eq("work@example.com")
      expect(flash[:alert]).to be_present
    end

    it "refuses to store a calendar when no account is connected" do
      patch integrations_google_calendar_path, params: { integration: { calendar_id: "work@example.com" } }

      expect(Integration.google_calendar).to be_nil
      expect(flash[:alert]).to be_present
    end

    it "keeps non-admins out" do
      Integration.create!(service_name: Integration::GOOGLE_CALENDAR)
      sign_in customer

      patch integrations_google_calendar_path, params: { integration: { calendar_id: "work@example.com" } }

      expect(response).to redirect_to(root_path)
      expect(Integration.google_calendar.calendar_id).to be_nil
    end
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
