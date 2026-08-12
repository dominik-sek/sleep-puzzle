class BookingsController < ApplicationController
  require 'google/apis/calendar_v3'

  before_action :authenticate_user!
  before_action :load_package_options, only: [ :index, :create ]

  def index
    load_availability

    @booking = Booking.new(
      name: current_user.full_name,
      email: current_user.email,
    )
  end

  # where Paddle sends the buyer once payment goes through; still pending at that
  # point, and flips to confirmed over a turbo stream when the webhook lands
  def show
    @booking = current_user.bookings.find_by!(token: params[:token])
  end

  def create
    @booking = Booking.new(
      user: current_user,
      name: booking_params[:name],
      starts_at: combined_starts_at,
      # taken from the account, never from the form: the field is only readonly
      # client-side and a posted value can't be trusted
      email: current_user.email,
      package_id: booking_params[:package_id],
      status: :pending,
    )

    if @booking.save
      BookingCalendarService.call(booking: @booking).create
      # held as pending until paddle_billing.transaction.completed arrives; see config/initializers/pay.rb
      @checkout = checkout_for(@booking)
      load_availability
      # reset to a blank form so the refreshed calendar is ready for another booking
      @booking = Booking.new(name: current_user.full_name, email: current_user.email)

      if @checkout
        flash.now[:notice] = "Termin wstępnie zarezerwowany. Dokończ płatność, aby go potwierdzić."
      else
        flash.now[:alert] = "Nie udało się otworzyć płatności. Spróbuj ponownie za chwilę."
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bookings_path, notice: flash.now[:notice] || flash.now[:alert] }
      end
    else
      render partial: "form",
             locals: { booking: @booking, package_options: @package_options, submitted_date: booking_params[:date], submitted_hour: booking_params[:hour] },
             status: :unprocessable_entity
    end
  end

  private

  # Paddle has to be handed a customer we already know about: Pay matches the
  # incoming webhook to a Pay::Customer by processor_id, and if checkout mints its
  # own anonymous customer instead there is nothing to match and the charge is
  # dropped. Calling api_record creates the Paddle customer and stores its id.
  def checkout_for(booking)
    {
      price_id: booking.package.paddle_price_id,
      customer_id: current_user.payment_processor.api_record.id,
      booking_id: booking.id,
      # Paddle closes the overlay and sends the buyer here once payment succeeds.
      # Must be absolute, and _url picks up the tunnel host in development.
      success_url: booking_url(booking)
    }
  # Paddle::Errors::* descend from Paddle::ErrorGenerator, not Paddle::Error, so Pay's
  # own rescue in Customer#api_record misses them and they arrive unwrapped
  rescue Pay::PaddleBilling::Error, Paddle::ErrorGenerator => e
    Rails.logger.error("Failed to prepare Paddle checkout for booking #{booking.id}: #{e.message}")
    nil
  end

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
    params.require(:booking).permit(:name, :date, :hour, :package_id)
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
