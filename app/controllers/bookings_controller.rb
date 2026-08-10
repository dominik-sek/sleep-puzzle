class BookingsController < ApplicationController
  require 'google/apis/calendar_v3'

  before_action :load_package_options, only: [ :index, :create ]

  def index
    load_availability

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
      status: :pending,
    )

    if @booking.save
      create_calendar_event(@booking)
      load_availability
      # reset to a blank form so the refreshed calendar is ready for another booking
      @booking = Booking.new(name: current_user&.full_name, email: current_user&.email)

      flash.now[:notice] = "Dziękujemy! Termin został zarezerwowany."
      respond_to do |format|
        format.turbo_stream
        # on payment success (webhook/callback): @booking.confirmed! then show it on the calendar
        format.html { redirect_to bookings_path, notice: "Dziękujemy! Termin został zarezerwowany." }
      end
    else
      render partial: "form",
             locals: { booking: @booking, package_options: @package_options, submitted_date: booking_params[:date], submitted_hour: booking_params[:hour] },
             status: :unprocessable_entity
    end
  end

  private

  def load_package_options
    @package_options = Package.order(:name).map do |package|
      [ package.name, package.id, { data: { price_id: package.paddle_price_id } } ]
    end
  end

  def load_availability
    busy_periods = GoogleCalendarService.call.busy
    available_blocks = SlotComparatorService.call(busy_periods: busy_periods)

    @availability = build_availability(available_blocks)

    # get the dates that have at least one available slot
    @available_dates = @availability[:dates].filter_map { |date|
      date[:date] if date[:hours].any? { |hour| hour[:available] }
    }.to_json
  end

  def combined_starts_at
    return nil if booking_params[:date].blank? || booking_params[:hour].blank?

    Time.zone.parse("#{booking_params[:date]} #{booking_params[:hour]}")
  end

  def booking_params
    params.require(:booking).permit(:name, :date, :hour, :email, :package_id)
  end

  def create_calendar_event(booking)
    GoogleCalendarService.call.create_event(
      summary: "Konsultacja – #{booking.name}",
      description: "Email: #{booking.email}\nPakiet: #{booking.package.name}",
      starts_at: booking.starts_at,
      ends_at: booking.starts_at + SlotComparatorService::SLOT_DURATION
    )
  rescue Google::Apis::Error => e
    Rails.logger.error("Failed to create Google Calendar event for booking #{booking.id}: #{e.message}")
  end

  # rebuild the full per-date slot list (available + unavailable) from the weekly
  # template, so booked slots still render as disabled buttons instead of vanishing
  def build_availability(available_blocks)
    available_starts = available_blocks.map(&:begin).to_set

    dates = schedule_dates.filter_map do |date|
      windows = SlotComparatorService::WEEKLY_SCHEDULE[date.wday]
      next if windows.blank?

      hours = windows.map do |starts_at, _ends_at|
        slot_start = Time.zone.parse("#{date} #{starts_at}")
        { hour: starts_at, available: available_starts.include?(slot_start) }
      end

      { date: date.iso8601, hours: hours }
    end

    { from: schedule_dates.first.iso8601, to: schedule_dates.last.iso8601, dates: dates }
  end

  def schedule_dates
    @schedule_dates ||= Date.current..SlotComparatorService::SCHEDULE_LENGTH.from_now.to_date
  end
end
