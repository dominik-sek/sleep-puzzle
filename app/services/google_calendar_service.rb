class GoogleCalendarService < ApplicationService
  # The owner's calendar cannot be reached at all: either it was never connected
  # in the panel, or the grant that was stored has since been revoked or expired.
  #
  # Deliberately not a Google::Apis::Error, which means one call failed while the
  # connection itself is fine. The two want different answers - a failed call is
  # worth retrying, a missing connection is only fixed by someone opening
  # /integrations/google_calendar and pressing connect - so callers that care can
  # tell them apart, and callers that don't rescue both.
  class NotConnected < StandardError; end

  def call
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.authorization = credentials
    self
  end

  def busy
    request = Google::Apis::CalendarV3::FreeBusyRequest.new(
      time_min: Time.current.beginning_of_day.iso8601,
      time_max: 2.months.from_now.end_of_day.iso8601,
      time_zone: Time.zone.tzinfo.name,
      items: [ Google::Apis::CalendarV3::FreeBusyRequestItem.new(id: ENV["GOOGLE_CALENDAR_ID"]) ]
    )

    response = @service.query_freebusy(request)
    response.calendars[ENV["GOOGLE_CALENDAR_ID"]].busy.map do |period|
      period.start.in_time_zone...period.end.in_time_zone
    end
  end

  def create_event(summary:, starts_at:, ends_at:, description: nil)
    event = Google::Apis::CalendarV3::Event.new(
      summary: summary,
      description: description,
      start: Google::Apis::CalendarV3::EventDateTime.new(date_time: starts_at.iso8601, time_zone: Time.zone.tzinfo.name),
      end: Google::Apis::CalendarV3::EventDateTime.new(date_time: ends_at.iso8601, time_zone: Time.zone.tzinfo.name)
    )

    @service.insert_event(ENV["GOOGLE_CALENDAR_ID"], event)
  end

  # partial update, so it can't clobber fields it isn't given
  def patch_event(event_id:, **attributes)
    @service.patch_event(ENV["GOOGLE_CALENDAR_ID"], event_id, Google::Apis::CalendarV3::Event.new(**attributes))
  end

  def delete_event(event_id:)
    @service.delete_event(ENV["GOOGLE_CALENDAR_ID"], event_id)
  end

  private

  # Two different nothings, one meaning. get_credentials returns nil when the
  # token store is empty, and raises when what is stored no longer works -
  # minting an access token from a revoked refresh token makes Google answer 400
  # "Token has been expired or revoked". Left as they come, the first silently
  # produces an unauthenticated service that only fails at the first API call,
  # and the second escapes as a Signet error nothing up the stack expects.
  def credentials
    google_calendar_authorizer.get_credentials(Integration::GOOGLE_CALENDAR) ||
      raise(NotConnected, "no Google Calendar is connected")
  rescue Signet::AuthorizationError => e
    raise NotConnected, "the stored Google Calendar grant is no longer valid (#{e.message})"
  end

  def google_calendar_authorizer
    AuthorizeCalendarService.call
  end
end
