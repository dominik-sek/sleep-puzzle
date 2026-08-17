# Adding to, changing and removing from the session cart.
#
# Every action answers with a turbo stream that re-renders the cart badge and the
# cart itself, so the count in the navbar stays honest without a full reload, and
# falls back to a redirect for a request that cannot take one.
class CartItemsController < ApplicationController
  before_action :load_product

  def create
    current_cart.add(@product, quantity: quantity_param || 1)

    respond_with_cart(notice: "#{@product.name} — dodano do koszyka.")
  end

  # A quantity of zero is a removal rather than an error: it is what the number
  # input produces when the buyer clears it.
  def update
    quantity = quantity_param.to_i

    if quantity.positive?
      current_cart.set_quantity(@product, quantity)
    else
      current_cart.remove(@product)
    end

    respond_with_cart
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

  def quantity_param
    params[:quantity] || params.dig(:cart_item, :quantity)
  end

  def respond_with_cart(notice: nil)
    flash.now[:notice] = notice if notice

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: cart_path, notice: notice }
    end
  end
end
