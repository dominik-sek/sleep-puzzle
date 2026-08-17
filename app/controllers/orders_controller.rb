# Checkout: hands the cart to the Paddle overlay the booking flow already drives.
#
# There is no payment screen of our own — the design draws one, but Paddle's
# overlay collects the card, so the only thing here is turning the session cart
# into a record Paddle's webhook can name.
class OrdersController < ApplicationController
  # Only checkout needs an account, not the cart: Paddle has to be handed a
  # customer we already know about, or the incoming webhook matches no
  # Pay::Customer and the charge is dropped. Devise sends the buyer back here
  # after signing in, and the session cart is still theirs on the way back.
  before_action :authenticate_user!

  # where Paddle sends the buyer once payment goes through; still pending at that
  # point, and flips to paid when the webhook lands
  def show
    @order = current_user.orders.includes(order_items: :product).find_by!(token: params[:token])
  end

  def create
    cart = current_cart

    return redirect_to cart_path, alert: "Twój koszyk jest pusty." if cart.empty?

    @order = build_order(cart)

    if @order.save
      @checkout = checkout_for(@order)

      if @checkout
        # The order now holds what the cart held, so the badge should drop to zero
        # as the overlay opens. #abandon puts it all back if the buyer closes the
        # overlay without paying — which is the only way out that leaves no
        # webhook behind.
        cart.clear
        flash.now[:notice] = "Dokończ płatność, aby sfinalizować zamówienie."
      else
        @order.destroy
        flash.now[:alert] = "Nie udało się otworzyć płatności. Spróbuj ponownie za chwilę."
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to cart_path, notice: flash.now[:notice] || flash.now[:alert] }
      end
    else
      redirect_to cart_path, alert: "Nie udało się rozpocząć płatności. Odśwież koszyk i spróbuj ponownie."
    end
  end

  # Closing the Paddle overlay fires no webhook — Paddle only reports transactions
  # the buyer actually attempted — so the browser reports it instead.
  #
  # The order is deleted rather than kept as canceled: nothing was paid, and a
  # discarded checkout should not leave an order in the buyer's history. Its lines
  # go back into the cart first, so closing the overlay by accident does not cost
  # the buyer the basket they just filled.
  def abandon
    order = current_user.orders.includes(order_items: :product).find_by!(token: params[:token])

    if order.pending? && order.paddle_transaction_id.blank?
      restore_cart(order)
      order.destroy!
      flash.now[:warning] = "Płatność została przerwana. Koszyk czeka na Ciebie."
    else
      # paid, or a webhook is already mid-flight: say nothing that claims the
      # money did not move
      flash.now[:notice] = "Sprawdzamy status płatności. Za chwilę pokażemy potwierdzenie."
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to cart_path }
    end
  end

  private

  def build_order(cart)
    order = current_user.orders.build(status: :pending)

    cart.lines.each { |line| order.order_items.build(product: line.product) }

    order
  end

  def restore_cart(order)
    order.order_items.each { |item| current_cart.add(item.product) }
  end

  # Paddle has to be handed a customer we already know about: Pay matches the
  # incoming webhook to a Pay::Customer by processor_id, and if checkout mints its
  # own anonymous customer instead there is nothing to match and the charge is
  # dropped. Calling api_record creates the Paddle customer and stores its id.
  def checkout_for(order)
    {
      items: order.paddle_items,
      customer_id: current_user.payment_processor.api_record.id,
      # the transaction.completed webhook reads this back to find the order
      custom_data: { order_id: order.id.to_s },
      # Must be absolute, and _url picks up the tunnel host in development.
      success_url: order_url(order),
      abandon_url: abandon_order_url(order)
    }
  # Paddle::Errors::* descend from Paddle::ErrorGenerator, not Paddle::Error, so Pay's
  # own rescue in Customer#api_record misses them and they arrive unwrapped
  rescue Pay::PaddleBilling::Error, Paddle::ErrorGenerator => e
    Rails.logger.error("Failed to prepare Paddle checkout for order #{order.id}: #{e.message}")
    nil
  end
end
