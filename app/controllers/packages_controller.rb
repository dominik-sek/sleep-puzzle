class PackagesController < ApplicationController
  include BookingAvailability

  def index
    @packages = Package.published.ordered
    load_availability
  end
end
