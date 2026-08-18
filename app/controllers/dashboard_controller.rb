# "Moje konto": what the buyer has bought, what they have booked, and where to
# change their details.
class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # deduplicated across orders, and only from orders Paddle has confirmed —
    # see User#purchased_products
    @products = current_user.purchased_products.ordered
    @bookings = current_user.bookings.upcoming.includes(:package)
  end
end
