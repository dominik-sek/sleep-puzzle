class SyncBookingCalendarJob < ApplicationJob
  queue_as :default
  retry_on GoogleCalendarService::NotConnected, Google::Apis::Error,
    Google::Auth::AuthorizationError, Signet::AuthorizationError,
    wait: :polynomially_longer, attempts: 10

  def perform(booking_id)
    ConsultationSetting.current.with_lock do
      booking = Booking.find_by(id: booking_id)
      return unless booking&.calendar_sync_pending?

      calendar = BookingCalendarService.call(booking: booking, strict: true)
      if booking.canceled? || booking.payment_failed?
        calendar.release if booking.starts_at > Time.current
      elsif booking.confirmed? || booking.pending?
        calendar.sync_schedule
      end
      booking.update!(calendar_sync_pending: false)
    end
  end
end
