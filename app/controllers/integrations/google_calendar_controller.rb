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
    revoke_remote_grant
    # Not left to revoke_authorization: it deletes through the token store only
    # after successfully building credentials, so the one case where the row most
    # needs to go - a grant Google has already dropped - is the case where it
    # never got that far.
    Integration.find_by(service_name: Integration::GOOGLE_CALENDAR)&.destroy

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

  # Best-effort, and deliberately not allowed to fail the disconnect.
  #
  # Both ways this blows up mean the grant on Google's side is already gone, which
  # is the state the button is trying to reach: revoking a token Google has
  # already expired answers 400, and refreshing a dead refresh token raises before
  # revoke_authorization reaches the revoke at all. Unrescued, the second one left
  # the panel permanently stuck - the row survived, the page kept saying
  # "Połączono", and pressing the button just 500'd again.
  def revoke_remote_grant
    authorizer.revoke_authorization(Integration::GOOGLE_CALENDAR)
  rescue Signet::AuthorizationError, Signet::UnexpectedStatusError => e
    Rails.logger.warn("Google Calendar revoke failed, disconnecting locally anyway: #{e.message}")
  end

  def authorizer
    AuthorizeCalendarService.call(callback_uri: callback_integrations_google_calendar_url)
  end
end
