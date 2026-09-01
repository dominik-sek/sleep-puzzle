# "Moje konto": what the buyer has bought, what they have booked, and where to
# change their details.
class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # deduplicated across orders, and only from orders Paddle has confirmed -
    # see User#purchased_products
    @products = current_user.purchased_products.ordered

    # Paid for, webhook not landed. Listed above the library rather than left
    # out: this screen used to say "you have no audio yet" to someone who had
    # just been charged, which is the worst sentence in the app.
    #
    # minus @products because a file bought twice - a second order opened before
    # the first cleared - is one file, and it belongs under the settled half.
    @awaiting = current_user.awaiting_products.ordered - @products
    @bookings = current_user.bookings.upcoming.includes(:package)
  end
end
