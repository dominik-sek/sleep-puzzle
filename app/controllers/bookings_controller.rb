class BookingsController < ApplicationController
  require "google/apis/calendar_v3"

  before_action :authenticate_user!
  before_action :load_package_options, only: [ :index, :create, :abandon ]

  def index
    load_availability

    @booking = Booking.new(
      name: current_user.full_name,
      email: current_user.email,
      # carried over from a package card's "Umów konsultację", so the choice made
      # on the packages page is not asked for a second time
      package_id: preselected_package_id
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

  # Closing the Paddle overlay fires no webhook — Paddle only reports transactions the
  # buyer actually attempted — so the browser reports it instead.
  #
  # The row is deleted rather than kept as canceled: nothing was paid and nothing was
  # committed to, so there is no history worth keeping, and a discarded checkout
  # shouldn't leave a booking behind in the buyer's dashboard or hold the slot until
  # ReleaseAbandonedBookingsJob sweeps it an hour later.
  def abandon
    booking = current_user.bookings.find_by!(token: params[:token])
    payment = BookingPaymentCheckService.call(booking: booking)
    cleared = clearable?(booking, payment)

    if cleared
      # drop the hold first: release nils calendar_event_id on the row, so doing it the
      # other way round would leave an orphaned event nothing knows how to find
      BookingCalendarService.call(booking: booking).release
      booking.destroy!
      Rails.logger.info("Cleared abandoned booking #{booking.id} — checkout closed without payment")
    end

    # always says something: the slot disappeared from the calendar when the booking was
    # created, so closing the overlay in silence leaves the buyer with no idea whether
    # they are booked, charged, or neither
    type, message = abandon_notice(cleared: cleared, payment: payment)
    flash.now[type] = message

    load_availability
    @booking = Booking.new(name: current_user.full_name, email: current_user.email)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to bookings_path }
    end
  end

  private

  # Deleting the row is irreversible, so the browser's word alone isn't enough: it says
  # the overlay closed, not that nothing was paid, and checkout.closed also fires when
  # Paddle tears the overlay down after a payment. Our own columns can't settle it
  # either — paddle_transaction_id is only written when the webhook lands — so the last
  # word goes to Paddle itself.
  def clearable?(booking, payment)
    booking.pending? && booking.paddle_transaction_id.blank? && payment.unpaid?
  end

  # Ordered by what the buyer most needs to know, and careful never to claim the slot is
  # free unless it is: a declined card leaves the transaction open, so "failed" and
  # "released" are not the same thing.
  def abandon_notice(cleared:, payment:)
    if payment.paid?
      [ :notice, "Płatność została zaksięgowana. Za chwilę pokażemy potwierdzenie rezerwacji." ]
    elsif payment.declined?
      [ :alert, "Płatność nie powiodła się. Termin nie został zarezerwowany - możesz spróbować ponownie." ]
    elsif cleared
      [ :warning, "Rezerwacja została anulowana. Termin jest znów dostępny." ]
    else
      [ :warning, "Rezerwacja nie została anulowana. Termin zwolni się automatycznie, jeśli płatność nie zostanie pomyślnie przetworzona." ]
    end
  end

  # Paddle has to be handed a customer we already know about: Pay matches the
  # incoming webhook to a Pay::Customer by processor_id, and if checkout mints its
  # own anonymous customer instead there is nothing to match and the charge is
  # dropped. Calling api_record creates the Paddle customer and stores its id.
  def checkout_for(booking)
    {
      items: [ { priceId: booking.package.paddle_price_id, quantity: 1 } ],
      customer_id: current_user.payment_processor.api_record.id,
      # the transaction.completed webhook reads this back to find the booking
      custom_data: { booking_id: booking.id.to_s },
      # Paddle closes the overlay and sends the buyer here once payment succeeds.
      # Must be absolute, and _url picks up the tunnel host in development.
      success_url: booking_url(booking),
      abandon_url: abandon_booking_url(booking)
    }
  # Paddle::Errors::* descend from Paddle::ErrorGenerator, not Paddle::Error, so Pay's
  # own rescue in Customer#api_record misses them and they arrive unwrapped
  rescue Pay::PaddleBilling::Error, Paddle::ErrorGenerator => e
    Rails.logger.error("Failed to prepare Paddle checkout for booking #{booking.id}: #{e.message}")
    nil
  end

  # Read through the published scope rather than trusted from the query string:
  # an unpublished or unknown id simply leaves the select on its prompt.
  def preselected_package_id
    Package.published.where(id: params[:package_id]).pick(:id)
  end

  def load_package_options
    @package_options = Package.published.ordered.map do |package|
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
