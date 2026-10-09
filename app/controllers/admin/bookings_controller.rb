# frozen_string_literal: true

module Admin
  class BookingsController < BaseController
    before_action :load_booking, only: %i[show cancel reschedule settlement]
    def index
      @status = params[:status] if Booking.statuses.key?(params[:status])

      scope = Booking.includes(:package, :user).order(starts_at: :desc)
      scope = scope.where(status: @status) if @status

      @pagy, @bookings = pagy(scope)
    end

    # deliberately not scoped to current_user the way BookingsController#show is:
    # the panel exists to look at other people's bookings
    def show
    end

    def cancel
      change_booking("canceled")
    end

    def reschedule
      change_booking("rescheduled")
    end

    def settlement
      note = params.require(:booking).permit(:settlement_notes)[:settlement_notes].to_s.strip
      if note.blank?
        @booking.errors.add(:base, "Wpisz wykonane czynności i uzasadnienie rozliczenia.")
        return render :show, status: :unprocessable_entity
      end
      @booking.with_lock do
        entry = "#{Time.current.iso8601} — #{current_user.email}\n#{note}"
        @booking.update!(settlement_notes: [ @booking.settlement_notes.presence, entry ].compact.join("\n\n"))
      end
      redirect_to admin_booking_path(@booking), notice: "Zapisano uzasadnienie rozliczenia."
    end

    private

    def load_booking
      @booking = Booking.find_by!(token: params[:token])
    end

    def change_booking(kind)
      fields = params.require(:booking).permit(:received_at, :reason, :initiator, :starts_at)
      changed = BookingChangeService.call(booking: @booking, admin: current_user, kind: kind,
        received_at: fields[:received_at].present? ? Time.zone.parse(fields[:received_at]) : nil,
        starts_at: fields[:starts_at].present? ? Time.zone.parse(fields[:starts_at]) : nil,
        reason: fields[:reason], initiator: fields[:initiator])
      if changed
        redirect_to admin_booking_path(@booking), notice: kind == "canceled" ? "Odwołano konsultację i zwolniono termin. Rozliczenie w Paddle wykonaj osobno." : "Zmieniono termin z zachowaniem płatności."
      else
        render :show, status: :unprocessable_entity
      end
    rescue ArgumentError
      @booking.errors.add(:base, "Wpisz poprawną datę i godzinę.")
      render :show, status: :unprocessable_entity
    end
  end
end
