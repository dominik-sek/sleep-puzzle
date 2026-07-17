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

    @booking = Booking.new
  end

  def new
    @booking = Booking.new
  end

  def create
    @booking = Booking.new(name: booking_params[:name], starts_at: combined_starts_at)

    if @booking.save
      redirect_to bookings_path, notice: "Dziękujemy! Termin został zarezerwowany."
    else
      redirect_to bookings_path, alert: @booking.errors.full_messages.to_sentence
    end
  end

  private

  def booking_params
    params.require(:booking).permit(:name, :date, :hour)
  end

  def combined_starts_at
    return nil if booking_params[:date].blank? || booking_params[:hour].blank?

    Time.zone.parse("#{booking_params[:date]} #{booking_params[:hour]}")
  end
end
