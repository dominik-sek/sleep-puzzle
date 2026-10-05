class ReserveConsultationService < ApplicationService
  def initialize(booking:)
    @booking = booking
  end

  def call
    settings = ConsultationSetting.current
    settings.with_lock do
      starts_at = @booking.starts_at
      if starts_at && settings.booking_dates.cover?(starts_at.to_date)
        busy = settings.local_availability? ? [] : GoogleCalendarService.call.busy
        available = SlotComparatorService.call(settings: settings, busy_periods: busy, from: starts_at.to_date, to: starts_at.to_date)
        return @booking.save if available.any? { |slot| slot.begin == starts_at }
      end
      @booking.errors.add(:starts_at, :invalid)
      false
    end
  rescue GoogleCalendarService::NotConnected, Google::Apis::Error,
         Google::Auth::AuthorizationError, Signet::AuthorizationError => error
    Rails.logger.error("Booking availability could not be checked: #{error.message}")
    @booking.errors.add(:starts_at, :invalid)
    false
  end
end
