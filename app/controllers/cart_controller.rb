# The cart screen. Signing in is not required here — only checkout needs an
# account, because Paddle has to be handed a customer we already know about.
class CartController < ApplicationController
  def show
  end

  def clear
    current_cart.clear

    redirect_to cart_path, notice: "Koszyk został opróżniony."
  end
end
