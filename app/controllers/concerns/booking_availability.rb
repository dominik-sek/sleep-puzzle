# frozen_string_literal: true
require "google/apis/calendar_v3"

# The public 1:1 landing and the signed-in checkout show the same availability.
# Only BookingsController may create a booking; this concern reads busy periods.
module BookingAvailability
  private

  def load_availability
    busy_periods = GoogleCalendarService.call.busy
    available_blocks = SlotComparatorService.call(busy_periods: busy_periods)
    @availability = build_availability(available_blocks)

    open_dates = @availability[:dates].filter_map do |date|
      date[:date] if date[:hours].any? { |hour| hour[:available] }
    end

    @no_slots = open_dates.empty?
    @available_dates = open_dates.to_json
  rescue GoogleCalendarService::NotConnected, Google::Apis::Error,
         Google::Auth::AuthorizationError, Signet::AuthorizationError => e
    Rails.logger.error("Booking availability could not be read: #{e.message}")
    @calendar_unavailable = true
    @availability = build_availability([])
    @no_slots = false
    @available_dates = [].to_json
  end

  def build_availability(available_blocks)
    available_starts = available_blocks.map(&:begin).to_set

    dates = schedule_dates.filter_map do |date|
      windows = SlotComparatorService::WEEKLY_SCHEDULE[date.wday]
      next if windows.blank?

      slot_starts = windows.map { |starts_at, _ends_at| Time.zone.parse("#{date} #{starts_at}") }
      hours = windows.zip(slot_starts).map do |(starts_at, _ends_at), slot_start|
        { hour: starts_at, available: available_starts.include?(slot_start) }
      end

      { date: date.iso8601, hours: hours, zone: helpers.booking_timezone_label(slot_starts.first) }
    end

    { from: schedule_dates.first.iso8601, to: schedule_dates.last.iso8601, dates: dates }
  end

  def schedule_dates
    @schedule_dates ||= Date.current..SlotComparatorService::SCHEDULE_LENGTH.from_now.to_date
  end
end
