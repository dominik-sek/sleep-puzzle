  class DashboardController < ApplicationController
  def index
    @user = current_user
    # @audiobooks = current_user.audiobooks.presence
    # @bookings = current_user.bookings.presence
  end
  end
