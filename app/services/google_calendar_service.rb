class GoogleCalendarService < ApplicationService
  def call
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.authorization = google_calendar_authorizer.get_credentials(Integration::GOOGLE_CALENDAR)
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
  def google_calendar_authorizer
    AuthorizeCalendarService.call
  end
end
