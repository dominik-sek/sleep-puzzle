class Integrations::GoogleCalendarController < ApplicationController
  before_action :authenticate_user!
  before_action :require_owner!

  def show
    @integration = Integration.find_by(service_name: Integration::GOOGLE_CALENDAR)
  end

  def connect
    redirect_to authorizer.get_authorization_url(request: request), allow_other_host: true
  end

  def callback
    authorizer.handle_auth_callback(Integration::GOOGLE_CALENDAR, request)
    redirect_to integrations_google_calendar_path, notice: "Kalendarz Google został połączony."
  rescue Google::Auth::AuthorizationError => e
    Rails.logger.warn("Google Calendar auth failed: #{e.message}")
    redirect_to integrations_google_calendar_path, alert: "Nie udało się połączyć z Kalendarzem Google. Spróbuj ponownie."
  end

  def destroy
    authorizer.revoke_authorization(Integration::GOOGLE_CALENDAR)
    redirect_to integrations_google_calendar_path, notice: "Kalendarz Google został odłączony."
  end

  private

  def require_owner!
    return if current_user&.email == ENV["OWNER_EMAIL"]
    redirect_to root_path, alert: "Brak dostępu."
  end

  def authorizer
    AuthorizeCalendarService.call(callback_uri: callback_integrations_google_calendar_url)
  end
end
