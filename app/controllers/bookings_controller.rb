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

    # Priceable first, and before anything is written. A package Paddle cannot
    # price is a package we cannot sell - the shop and the packages page both
    # enforce that by withholding the buy control, and this surface used to be
    # the one place the rule was dropped.
    if @booking.package && !package_priceable?(@booking.package)
      @booking.errors.add(:package_id, :unpriceable)
      return render partial: "form",
                    locals: { booking: @booking, package_options: @package_options,
                              submitted_date: booking_params[:date], submitted_hour: booking_params[:hour] },
                    status: :unprocessable_entity
    end

    if @booking.save
      # The checkout payload needs the persisted id and the booking's own URL, so
      # it cannot be prepared before the save. What it can do is come before the
      # calendar hold: a slot is only taken off the public calendar once there is
      # something to pay with. If Paddle fails here the row is removed again, so
      # no orphan pending booking sits in the buyer's dashboard for an hour.
      @checkout = checkout_for(@booking)

      if @checkout
        BookingCalendarService.call(booking: @booking).create
        flash.now[:notice] = booking_message("reserved")
      else
        @booking.destroy!
        flash.now[:alert] = booking_message("checkout_failed")
      end

      load_availability
      # reset to a blank form so the refreshed calendar is ready for another booking
      @booking = Booking.new(name: current_user.full_name, email: current_user.email)

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

  # Closing the Paddle overlay fires no webhook - Paddle only reports transactions the
  # buyer actually attempted - so the browser reports it instead.
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
      Rails.logger.info("Cleared abandoned booking #{booking.id} - checkout closed without payment")
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
  # either - paddle_transaction_id is only written when the webhook lands - so the last
  # word goes to Paddle itself.
  def clearable?(booking, payment)
    booking.pending? && booking.paddle_transaction_id.blank? && payment.unpaid?
  end

  # Ordered by what the buyer most needs to know, and careful never to claim the slot is
  # free unless it is: a declined card leaves the transaction open, so "failed" and
  # "released" are not the same thing.
  def abandon_notice(cleared:, payment:)
    if payment.paid?
      [ :notice, booking_message("paid") ]
    elsif payment.declined?
      [ :alert, booking_message("declined") ]
    elsif cleared
      [ :warning, booking_message("released") ]
    else
      [ :warning, booking_message("not_released") ]
    end
  end

  # Paddle has to be handed a customer we already know about: Pay matches the
  # incoming webhook to a Pay::Customer by processor_id, and if checkout mints its
  # own anonymous customer instead there is nothing to match and the charge is
  # dropped. Calling api_record creates the Paddle customer and stores its id.
  # Paddle owns the money, so "can this be sold" is a question only the price
  # catalogue can answer. nil means archived in Paddle, or Paddle unreachable.
  def package_priceable?(package)
    PaddlePriceCatalogService.find(package.paddle_price_id).present?
  end

  # These are the sentences a buyer reads at the moment money moves, so they
  # belong to the owner like every other public word - Principle 4. helpers.
  # reaches the same content_block the views use, defaults and all.
  def booking_message(key)
    helpers.content_block("bookings.messages.#{key}")
  end

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

  # data-price carries the already-formatted amount so the summary can update
  # without a round trip, while PaddlePriceCatalogService stays the only thing
  # that formats money. data-duration likewise: the buyer was never told a
  # consultation is 90 minutes.
  def load_package_options
    @package_options = Package.published.ordered.map do |package|
      price = PaddlePriceCatalogService.find(package.paddle_price_id)&.formatted_amount

      [ package.name, package.id, {
        data: {
          price_id: package.paddle_price_id,
          price: price,
          duration: package.duration ? t("packages.duration", count: package.duration) : nil
        }
      } ]
    end
  end

  def load_availability
    busy_periods = GoogleCalendarService.call.busy
    available_blocks = SlotComparatorService.call(busy_periods: busy_periods)

    @availability = build_availability(available_blocks)

    # get the dates that have at least one available slot
    open_dates = @availability[:dates].filter_map { |date|
      date[:date] if date[:hours].any? { |hour| hour[:available] }
    }

    # the view needs the boolean as well as the payload: @available_dates is JSON
    # for the calendar element, and "[]" is not blank, so the empty case cannot be
    # read off it without parsing it back
    @no_slots = open_dates.empty?
    @available_dates = open_dates.to_json
  rescue GoogleCalendarService::NotConnected, Google::Apis::Error => e
    # No calendar means no way to know what the owner is already busy with, and
    # this page used to 500 outright rather than say so. Every slot is rendered
    # taken rather than free, because free would be a guess and a wrong guess
    # sells a time she is already sitting in someone else's consultation for.
    # `build_availability([])` is the honest version of that: the same grid the
    # page always draws, with nothing in it selectable.
    Rails.logger.error("Booking availability could not be read: #{e.message}")

    @calendar_unavailable = true
    @availability = build_availability([])
    @no_slots = false # unreadable is a different nothing; that banner owns it
    @available_dates = [].to_json
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

      slot_starts = windows.map { |starts_at, _ends_at| Time.zone.parse("#{date} #{starts_at}") }

      hours = windows.zip(slot_starts).map do |(starts_at, _ends_at), slot_start|
        { hour: starts_at, available: available_starts.include?(slot_start) }
      end

      # the offset is this date's own, not the page's - see BookingsHelper
      { date: date.iso8601, hours: hours, zone: helpers.booking_timezone_label(slot_starts.first) }
    end

    { from: schedule_dates.first.iso8601, to: schedule_dates.last.iso8601, dates: dates }
  end

  def schedule_dates
    @schedule_dates ||= Date.current..SlotComparatorService::SCHEDULE_LENGTH.from_now.to_date
  end
end
