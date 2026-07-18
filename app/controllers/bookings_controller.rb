class BookingsController < ApplicationController
  def index
    # mock shape for the 2-month prefetch discussed for the calendar — swap for a real
    # query once we have bookings/business-hours to compute availability from.
    #
    # sparse on purpose: a date not listed here (or with an empty "hours" array) means
    # fully unavailable, so we don't have to enumerate every day/weekend with nothing open.
    @availability = {
      from: "2026-07-16",
      to: "2026-09-16",
      dates: [
        {
          date: "2026-07-17",
          hours: [
            { hour: "12:00", available: true },
            { hour: "12:30", available: true },
            { hour: "13:00", available: false },
            { hour: "14:00", available: true },
            { hour: "14:30", available: false },
            { hour: "15:00", available: false },
            { hour: "15:30", available: false },
            { hour: "15:00", available: false },
            { hour: "15:30", available: false },
            { hour: "15:00", available: false },
            { hour: "15:30", available: false },
            { hour: "15:00", available: false },
            { hour: "15:30", available: false },
          ]
        },
        {
          date: "2026-07-18",
          hours: [
            { hour: "12:00", available: false },
            { hour: "12:30", available: false },
            { hour: "13:00", available: false },
            { hour: "14:00", available: false }
          ]
        },
        {
          date: "2026-07-20",
          hours: [
            { hour: "12:00", available: true },
            { hour: "14:00", available: true }
          ]
        }
      ]
    }

    # get the dates that have at least one available slot
    @available_dates = @availability[:dates].filter_map { |date|
      date[:date] if date[:hours].any? { |hour| hour[:available] }
    }.to_json

    @booking = Booking.new(
      name: current_user&.full_name,
      email: current_user&.email,
    )
  end

  def create
    @booking = Booking.new(
      name: booking_params[:name],
      starts_at: combined_starts_at,
      email: booking_params[:email],
      package_id: booking_params[:package_id],
    )

    if @booking.save
      redirect_to bookings_path, notice: "Dziękujemy! Termin został zarezerwowany."
    else
      render partial: "form",
             locals: { booking: @booking, submitted_date: booking_params[:date], submitted_hour: booking_params[:hour] },
             status: :unprocessable_entity
    end
  end

  private

  def combined_starts_at
    return nil if booking_params[:date].blank? || booking_params[:hour].blank?

    Time.zone.parse("#{booking_params[:date]} #{booking_params[:hour]}")
  end

  def booking_params
    params.require(:booking).permit(:name, :date, :hour, :email, :package_id)
  end
end
