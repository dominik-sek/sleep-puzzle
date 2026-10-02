class PackagesController < ApplicationController
  include BookingAvailability

  def index
    @packages = Package.published.ordered
    load_availability unless user_signed_in?
  end
end
