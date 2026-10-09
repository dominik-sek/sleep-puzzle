class BookingChangeService < ApplicationService
  def initialize(booking:, admin:, kind:, received_at:, reason:, initiator:, starts_at: nil)
    @booking, @admin, @kind = booking, admin, kind
    @received_at, @reason, @initiator, @starts_at = received_at, reason, initiator, starts_at
  end

  def call
    settings = ConsultationSetting.current
    settings.with_lock do
      @booking.reload
      unless @booking.status.in?(%w[pending confirmed])
        @booking.errors.add(:base, "Ta rezerwacja nie jest aktywna.")
        return false
      end

      @change = @booking.booking_changes.build(admin: @admin, kind: @kind,
        received_at: @received_at, reason: @reason, initiator: @initiator,
        previous_starts_at: @booking.starts_at, new_starts_at: @starts_at)
      unless @change.valid?
        @booking.errors.add(:base, @change.errors.full_messages.join(", "))
        return false
      end

      if @kind == "rescheduled"
        return false unless reschedulable?(settings)

        @booking.update!(starts_at: @starts_at, ends_at: @starts_at + SlotComparatorService::SLOT_DURATION,
          calendar_sync_pending: true)
      else
        @booking.update!(status: :canceled, canceled_at: Time.current, calendar_sync_pending: true)
      end
      @change.save!
    end

    SyncBookingCalendarJob.perform_later(@booking.id)
    BookingMailer.with(change: @change).changed.deliver_later
    @booking.broadcast_replace_to @booking, target: "booking_status", partial: "bookings/status", locals: { booking: @booking }
    true
  rescue GoogleCalendarService::NotConnected, Google::Apis::Error,
         Google::Auth::AuthorizationError, Signet::AuthorizationError => error
    Rails.logger.error("Could not check reschedule availability: #{error.message}")
    @booking.errors.add(:base, "Nie udało się sprawdzić dostępności nowego terminu.")
    false
  end

  private

  def reschedulable?(settings)
    unless @booking.confirmed? && @starts_at && @starts_at != @booking.starts_at
      @booking.errors.add(:base, "Wybierz inny termin opłaconej konsultacji.")
      return false
    end
    if @starts_at < ((@booking.confirmed_at || @booking.created_at) + 14.days) && !@booking.consent_accepted_at?
      @booking.errors.add(:base, "Brak zgody klienta na rozpoczęcie usługi przed upływem 14 dni od zakupu.")
      return false
    end
    busy = settings.local_availability? ? [] : GoogleCalendarService.call.busy(except_event_id: @booking.calendar_event_id)
    available = SlotComparatorService.call(settings: settings, busy_periods: busy,
      from: @starts_at.to_date, to: @starts_at.to_date, excluding_booking_id: @booking.id)
    return true if available.any? { |slot| slot.begin == @starts_at }

    @booking.errors.add(:base, "Wybrany termin jest niedostępny.")
    false
  end
end
