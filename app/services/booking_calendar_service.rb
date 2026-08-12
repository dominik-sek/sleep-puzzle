# Keeps the Google Calendar event in step with a booking's payment status, so the
# calendar itself shows whether a slot is paid for or still waiting.
#
# Every method swallows Google::Apis::Error: the calendar is a side effect of the
# booking, and a calendar outage must not roll back a payment we've already taken.
class BookingCalendarService < ApplicationService
  def initialize(booking:)
    @booking = booking
  end

  # mirrors GoogleCalendarService's own idiom: .call sets up, then you send a verb
  def call
    self
  end

  def create
    event = calendar.create_event(
      summary: summary,
      description: description,
      starts_at: @booking.starts_at,
      ends_at: @booking.starts_at + SlotComparatorService::SLOT_DURATION
    )
    @booking.update!(calendar_event_id: event.id)
  rescue Google::Apis::Error => e
    log(e, "create")
  end

  # rewrites title and description so the new payment status is visible at a glance
  def sync_status
    return if @booking.calendar_event_id.blank?

    calendar.patch_event(event_id: @booking.calendar_event_id, summary: summary, description: description)
  rescue Google::Apis::Error => e
    log(e, "update")
  end

  # payment failed or was abandoned — drop the hold so the slot frees up again
  def release
    return if @booking.calendar_event_id.blank?

    begin
      calendar.delete_event(event_id: @booking.calendar_event_id)
    rescue Google::Apis::ClientError => e
      # An event that is already gone is the state we wanted, not a failure. Without
      # this the retry raises, the id is never cleared, and the booking is stuck
      # holding a dead event id forever.
      raise unless e.message.match?(/notFound|deleted/i)
    end

    @booking.update!(calendar_event_id: nil)
  rescue Google::Apis::Error => e
    log(e, "delete")
  end

  private

  def calendar
    @calendar ||= GoogleCalendarService.call
  end

  def payment_status
    Booking::PAYMENT_STATUS_LABELS.fetch(@booking.status)
  end

  def summary
    "Konsultacja – #{@booking.name} (#{payment_status})"
  end

  def description
    [
      "Email: #{@booking.email}",
      "Pakiet: #{@booking.package.name}",
      "Status płatności: #{payment_status}"
    ].join("\n")
  end

  def log(error, action)
    Rails.logger.error("Failed to #{action} Google Calendar event for booking #{@booking.id}: #{error.message}")
    nil
  end
end
