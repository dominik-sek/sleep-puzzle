# Adding to and removing from the session cart.
#
# There is no update action: everything sold here is a digital file, so a line is
# either in the cart or it is not, and the shop's button is a toggle rather than
# a counter.
#
# Both actions answer with a turbo stream that re-renders the cart, the navbar
# badge, the shop's cart pill and the toggle itself, so nothing on screen can
# disagree about what is in the cart. They fall back to a redirect for a request
# that cannot take a stream.
class CartItemsController < ApplicationController
  before_action :load_product

  def create
    # The button already says "W Twoim koncie" for something owned, but this POST
    # is reachable without it — a stale page, a direct request — and a digital
    # file bought twice is money taken for nothing.
    if current_user&.purchased?(@product)
      return respond_with_cart(alert: "#{@product.name} — masz już to nagranie na swoim koncie.")
    end

    current_cart.add(@product)

    respond_with_cart(notice: "#{@product.name} — dodano do koszyka.")
  end

  def destroy
    current_cart.remove(@product)

    respond_with_cart(notice: "#{@product.name} — usunięto z koszyka.")
  end

  private

  # Through the published scope: an unpublished product should not be addable,
  # and a forged or stale id should 404 rather than put a nil in the session.
  def load_product
    @product = Product.published.find(params[:product_id] || params[:cart_item][:product_id])
  end

  def respond_with_cart(notice: nil, alert: nil)
    flash.now[:notice] = notice if notice
    flash.now[:alert] = alert if alert

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: cart_path, notice: notice, alert: alert }
    end
  end
end
