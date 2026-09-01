class Integrations::GoogleCalendarController < ApplicationController
  # Admin-only and linked from the panel's sidebar, so it wears the panel's
  # chrome. Without this the sidebar link led out of the panel and onto a page
  # with the public navbar and footer, which is a strange place to land.
  layout "admin"

  before_action :authenticate_user!
  before_action :require_admin

  def show
    @integration = Integration.google_calendar
    @calendar_id = Integration.google_calendar_id
    @calendars = @integration && writable_calendars
  end

  # Which calendar the bookings land in. Used to be GOOGLE_CALENDAR_ID, which
  # meant a redeploy to change and a raw id to find by hand.
  def update
    integration = Integration.google_calendar
    calendar_id = params.dig(:integration, :calendar_id).presence

    if integration.nil?
      redirect_to integrations_google_calendar_path, alert: "Najpierw połącz konto Google."
    elsif calendar_id.blank?
      redirect_to integrations_google_calendar_path, alert: "Wybierz kalendarz z listy."
    else
      integration.update!(calendar_id: calendar_id)
      redirect_to integrations_google_calendar_path, notice: "Kalendarz został zapisany."
    end
  end

  def connect
    redirect_to authorizer.get_authorization_url(request: request), allow_other_host: true
  end

  def callback
    authorizer.handle_auth_callback(Integration::GOOGLE_CALENDAR, request)
    redirect_to integrations_google_calendar_path, notice: "Konto Google zostało połączone. Wybierz kalendarz poniżej."
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

  # nil, not [], when the list cannot be read: an empty list means the account
  # genuinely owns no writable calendar, and the panel says different things
  # about that than about a call to Google that failed.
  def writable_calendars
    GoogleCalendarService.call.writable_calendars
  rescue GoogleCalendarService::NotConnected, Google::Apis::Error => e
    Rails.logger.warn("Could not list Google calendars: #{e.message}")
    nil
  end

  def authorizer
    AuthorizeCalendarService.call(callback_uri: callback_integrations_google_calendar_url)
  end
end
