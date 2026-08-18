class Integrations::GoogleCalendarController < ApplicationController
  # Admin-only and linked from the panel's sidebar, so it wears the panel's
  # chrome. Without this the sidebar link led out of the panel and onto a page
  # with the public navbar and footer, which is a strange place to land.
  layout "admin"

  before_action :authenticate_user!
  before_action :require_admin

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

  # Same rule as every other gated screen: the `admin` boolean on users, granted
  # with `bin/rails 'admin:promote[…]'`. This used to compare against OWNER_EMAIL,
  # which allowed exactly one person and needed a redeploy to change. OWNER_EMAIL
  # is only the notification inbox now, and says nothing about who may sign in.
  def require_admin
    return if current_user&.admin?

    redirect_to root_path, alert: "Brak dostępu."
  end

  def authorizer
    AuthorizeCalendarService.call(callback_uri: callback_integrations_google_calendar_url)
  end
end
