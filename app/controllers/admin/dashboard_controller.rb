# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    UPCOMING_LIMIT = 5
    RECENT_LIMIT = 8

    def index
      @upcoming_count = upcoming_bookings_scope.count
      @pending_count = Booking.pending.count
      @confirmed_count = Booking.confirmed.count
      @users_count = User.count

      @upcoming_bookings = upcoming_bookings_scope
                             .includes(:package, :user)
                             .order(:starts_at)
                             .limit(UPCOMING_LIMIT)

      @recent_bookings = Booking.includes(:package, :user)
                                .order(created_at: :desc)
                                .limit(RECENT_LIMIT)
    end

    private

    def upcoming_bookings_scope
      Booking.confirmed.where(starts_at: Time.current..)
    end
  end
end
