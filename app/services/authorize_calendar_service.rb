class AuthorizeCalendarService < ApplicationService
  SCOPE = [
    Google::Apis::CalendarV3::AUTH_CALENDAR_EVENTS,
    Google::Apis::CalendarV3::AUTH_CALENDAR_FREEBUSY,
    Google::Apis::CalendarV3::AUTH_CALENDAR_CALENDARLIST,
    Google::Apis::CalendarV3::AUTH_CALENDAR
  ].freeze

  def initialize(callback_uri: nil)
    @callback_uri = callback_uri
  end

  def call
    Google::Auth::WebUserAuthorizer.new(
      Google::Auth::ClientId.new(ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"]),
      SCOPE,
      Integration::TokenStore.new,
      callback_uri: @callback_uri
    )
  end
end
