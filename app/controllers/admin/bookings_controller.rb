# frozen_string_literal: true

module Admin
  class BookingsController < BaseController
    def index
      @status = params[:status] if Booking.statuses.key?(params[:status])

      scope = Booking.includes(:package, :user).order(starts_at: :desc)
      scope = scope.where(status: @status) if @status

      @pagy, @bookings = pagy(scope)
    end

    # deliberately not scoped to current_user the way BookingsController#show is:
    # the panel exists to look at other people's bookings
    def show
      @booking = Booking.find_by!(token: params[:token])
    end
  end
end
