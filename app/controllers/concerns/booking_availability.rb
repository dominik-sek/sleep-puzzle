# frozen_string_literal: true

require "google/apis/calendar_v3"

module BookingAvailability
  private

  def load_availability
    @consultation_settings = ConsultationSetting.current
    busy_periods = @consultation_settings.local_availability? ? [] : GoogleCalendarService.call.busy
    available_blocks = SlotComparatorService.call(settings: @consultation_settings, busy_periods: busy_periods)
    @availability = build_availability(available_blocks)
    open_dates = @availability[:dates].filter_map do |date|
      date[:date] if date[:hours].any? { |hour| hour[:available] }
    end
    @no_slots = open_dates.empty?
    @available_dates = open_dates.to_json
  rescue GoogleCalendarService::NotConnected, Google::Apis::Error,
         Google::Auth::AuthorizationError, Signet::AuthorizationError => error
    Rails.logger.error("Booking availability could not be read: #{error.message}")
    @calendar_unavailable = true
    @availability = build_availability([])
    @no_slots = false
    @available_dates = [].to_json
  end

  def build_availability(available_blocks)
    settings = @consultation_settings || ConsultationSetting.current
    available_starts = available_blocks.map(&:begin).to_set
    dates = SlotComparatorService.new(settings: settings).schedule_blocks.group_by { |block| block.begin.to_date }.map do |date, blocks|
      { date: date.iso8601,
        hours: blocks.map { |block| { hour: block.begin.strftime("%H:%M"), available: available_starts.include?(block.begin) } },
        zone: helpers.booking_timezone_label(blocks.first.begin) }
    end
    { from: settings.booking_dates.first.iso8601, to: settings.booking_dates.last.iso8601, dates: dates }
  end
end
