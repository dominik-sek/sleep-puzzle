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

  # Connected, but nobody has picked which calendar to write to yet. Same family
  # as NotConnected because the answer is the same - open the panel and finish
  # setting it up - and callers already treat that as "no calendar today".
  class NoCalendarSelected < NotConnected; end

  def call
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.authorization = credentials
    self
  end

  # Everything on the calendar blocks a slot, including what Google calls "free".
  #
  # This used to ask freebusy, which is the obvious API for the question and the
  # wrong one: it silently drops every event marked transparent, and Google
  # Calendar marks all-day events that way by default. A week of "urlop" entered
  # the normal way therefore blocked nothing at all, and the slots inside it
  # stayed on sale. Reading the events themselves is the only way to see them.
  #
  # Transparency is ignored rather than honoured on purpose: an event wrongly
  # treated as busy costs one needlessly blocked slot, which is visible and
  # fixable, while one wrongly treated as free sells a time she is not available.
  def busy
    events.filter_map { |event| period(event) }
  end

  def create_event(summary:, starts_at:, ends_at:, description: nil)
    event = Google::Apis::CalendarV3::Event.new(
      summary: summary,
      description: description,
      start: Google::Apis::CalendarV3::EventDateTime.new(date_time: starts_at.iso8601, time_zone: Time.zone.tzinfo.name),
      end: Google::Apis::CalendarV3::EventDateTime.new(date_time: ends_at.iso8601, time_zone: Time.zone.tzinfo.name)
    )

    @service.insert_event(calendar_id, event)
  end

  # partial update, so it can't clobber fields it isn't given
  def patch_event(event_id:, **attributes)
    @service.patch_event(calendar_id, event_id, Google::Apis::CalendarV3::Event.new(**attributes))
  end

  def delete_event(event_id:)
    @service.delete_event(calendar_id, event_id)
  end

  # The calendars the grant may write events into, for the panel's picker.
  # min_access_role does the filtering server-side: a calendar someone only
  # subscribed to cannot hold a booking.
  def writable_calendars
    @service.list_calendar_lists(min_access_role: "writer").items.sort_by do |calendar|
      [ calendar.primary? ? 0 : 1, calendar.summary.to_s.downcase ]
    end
  end

  private

  # single_events expands a recurring event into the occurrences that actually
  # take up time; without it a weekly commitment arrives as one row and blocks
  # nothing after the first. Paged because a calendar the owner also lives in can
  # hold more than one page of events over two months, and a dropped page reads
  # as free time.
  def events
    items = []
    page_token = nil

    loop do
      page = @service.list_events(
        calendar_id,
        time_min: Time.current.beginning_of_day.iso8601,
        time_max: SlotComparatorService::SCHEDULE_LENGTH.from_now.end_of_day.iso8601,
        single_events: true,
        order_by: "startTime",
        max_results: 250,
        page_token: page_token
      )

      items.concat(page.items)
      page_token = page.next_page_token
      break if page_token.blank?
    end

    items
  end

  # Two shapes in one field: a timed event carries date_time, an all-day event
  # carries a bare date. Google's all-day end date is exclusive, so 11th-to-12th
  # is one day off rather than two, and midnight to midnight is exactly that.
  def period(event)
    if event.start&.date
      event.start.date.in_time_zone...event.end.date.in_time_zone
    elsif event.start&.date_time
      event.start.date_time.in_time_zone...event.end.date_time.in_time_zone
    end
  end

  # Connecting the account and choosing a calendar are two steps, and the gap
  # between them is a real state: everything below would otherwise call Google
  # with a nil id and get back a confusing 404 about "calendar not found".
  def calendar_id
    @calendar_id ||= Integration.google_calendar_id ||
      raise(NoCalendarSelected, "no calendar has been selected for the connected Google account")
  end

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
