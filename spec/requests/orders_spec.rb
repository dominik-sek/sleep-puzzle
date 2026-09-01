require 'rails_helper'

RSpec.describe "Orders", type: :request do
  let(:user) { User.create!(email: "customer@example.com", password: "password123") }
  let(:product) { create_product(name: "Bajka o sowie") }

  before do
    allow(PaddlePriceCatalogService).to receive(:call)
      .and_return([ paddle_price(id: "pri_456", amount: "2500", currency: "PLN") ])
    # Paddle has to be handed a customer we already know about; creating it for
    # real would reach the network
    allow_any_instance_of(User).to receive(:payment_processor)
      .and_return(double(api_record: double(id: "ctm_123")))
  end

  def fill_cart(with: product)
    post cart_items_path, params: { product_id: with.id }
  end

  # the whole bug: from the moment the overlay opens until the webhook lands,
  # every commerce surface used to read the order as though it did not exist
  describe "while a payment is in flight" do
    before { sign_in user }

    let!(:order) do
      user.orders.create!(status: :pending, order_items: [ OrderItem.new(product: product) ])
    end

    it "refuses to put the product back in the cart" do
      post cart_items_path, params: { product_id: product.id }

      expect(Cart.from_session(session, owner: user).lines).to be_empty
    end

    it "will not open a second checkout for it" do
      post cart_items_path, params: { product_id: product.id }

      expect { post orders_path }.not_to change(Order, :count)
    end

    it "shows it on the account as awaiting rather than missing" do
      get dashboard_index_path

      expect(response.body).to include("Bajka o sowie")
      expect(response.body).to include("Płatność w trakcie")
    end

    it "says the payment is still going through rather than confirming it" do
      get order_path(order)

      expect(response.body).to include("Potwierdzamy płatność")
      expect(response.body).not_to include("Dziękujemy za zakup")
    end

    it "confirms it once the order is paid" do
      order.mark_paid!(transaction_id: "txn_1")

      get order_path(order)

      expect(response.body).to include("Dziękujemy za zakup")
    end

    it "says nothing was taken once the order fails" do
      order.fail_payment!(:payment_failed)

      get order_path(order)

      expect(response.body).to include("Płatność nie doszła do skutku")
    end

    it "puts the product back on sale once the order fails" do
      order.fail_payment!(:canceled)

      post cart_items_path, params: { product_id: product.id }

      expect(Cart.from_session(session, owner: user).lines.map(&:product)).to eq([ product ])
    end
  end

  describe "POST /orders" do
    it "sends an anonymous buyer to sign in rather than to Paddle" do
      fill_cart

      post orders_path

      expect(response).to redirect_to(new_user_session_path)
      expect(Order.count).to eq(0)
    end

    context "when signed in" do
      before { sign_in user }

      it "turns the cart into a pending order" do
        fill_cart

        post orders_path

        order = Order.sole
        expect(order).to be_pending
        expect(order.user).to eq(user)
        expect(order.order_items.sole.product).to eq(product)
      end

      it "hands Paddle every line" do
        other = create_product(name: "Audioproces", paddle_price_id: "pri_789")
        fill_cart
        fill_cart(with: other)

        post orders_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include("pri_456")
        expect(response.body).to include("pri_789")
        expect(response.body).to include("&quot;quantity&quot;:1")
        expect(response.body).to include("ctm_123")
      end

      # the order holds what the cart held, so the badge should drop to zero as
      # the overlay opens; #abandon puts it all back
      it "empties the cart once the order exists" do
        fill_cart

        post orders_path

        get cart_path
        expect(response.body).to include("Twój koszyk jest pusty")
      end

      # the last line of defence: the cart already filters owned files, so an
      # order must never be able to carry one
      it "never charges for something the buyer already owns" do
        owned = create_product(name: "Już kupione", paddle_price_id: "pri_789")
        user.orders.create!(status: :pending, order_items: [ OrderItem.new(product: owned) ])
          .mark_paid!(transaction_id: "txn_old")
        sign_out user
        fill_cart
        fill_cart(with: owned)
        sign_in user

        post orders_path

        # the paid one is the pre-existing purchase; the new order is the pending one
        order = Order.pending.sole
        expect(order.products).to eq([ product ])
      end

      it "refuses a cart holding nothing but things already owned" do
        sign_out user
        fill_cart
        sign_in user
        user.orders.create!(status: :pending, order_items: [ OrderItem.new(product: product) ])
          .mark_paid!(transaction_id: "txn_old")

        post orders_path

        expect(response).to redirect_to(cart_path)
        expect(Order.pending).to be_empty
      end

      it "refuses an empty cart" do
        post orders_path

        expect(response).to redirect_to(cart_path)
        expect(Order.count).to eq(0)
      end

      # nothing was charged, so the buyer should not be left with an order they
      # cannot pay for and an emptied cart
      it "keeps neither the order nor an emptied cart when Paddle cannot be reached" do
        fill_cart
        # raised from inside a rescue, the way Pay does it: Pay::Error delegates
        # #message to its cause, so one without a cause is not a realistic failure
        allow_any_instance_of(User).to receive(:payment_processor) do
          begin
            raise Paddle::Error, "paddle is down"
          rescue Paddle::Error
            raise Pay::PaddleBilling::Error
          end
        end

        post orders_path

        expect(Order.count).to eq(0)
        get cart_path
        expect(response.body).to include("Bajka o sowie")
      end
    end
  end

  describe "DELETE /orders/:token/abandon" do
    before { sign_in user }

    it "deletes the pending order and puts its lines back in the cart" do
      other = create_product(name: "Audioproces", paddle_price_id: "pri_789")
      fill_cart
      fill_cart(with: other)
      post orders_path
      order = Order.sole

      delete abandon_order_path(order)

      expect(Order.count).to eq(0)
      get cart_path
      expect(response.body).to include("Bajka o sowie")
      expect(response.body).to include("Audioproces")
    end

    # closing the overlay after paying fires checkout.closed too, so the browser
    # saying "closed" must never delete an order the webhook has already claimed
    it "leaves a paid order alone" do
      fill_cart
      post orders_path
      order = Order.sole
      order.mark_paid!(transaction_id: "txn_1")

      delete abandon_order_path(order)

      expect(order.reload).to be_paid
    end

    it "does not let one buyer abandon another's order" do
      fill_cart
      post orders_path
      order = Order.sole

      sign_in User.create!(email: "someone@example.com", password: "password123")
      delete abandon_order_path(order)

      expect(response).to have_http_status(:not_found)
      expect(order.reload).to be_present
    end
  end

  describe "GET /orders/:token" do
    before { sign_in user }

    it "says the payment is still being confirmed while the order is pending" do
      fill_cart
      post orders_path

      get order_path(Order.sole)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Potwierdzamy płatność")
      expect(response.body).to include("Bajka o sowie")
    end

    it "thanks the buyer once the webhook has marked it paid" do
      fill_cart
      post orders_path
      Order.sole.mark_paid!(transaction_id: "txn_1")

      get order_path(Order.sole)

      expect(response.body).to include("Dziękujemy za zakup")
    end

    it "is not readable by another buyer" do
      fill_cart
      post orders_path
      order = Order.sole

      sign_in User.create!(email: "someone@example.com", password: "password123")
      get order_path(order)

      expect(response).to have_http_status(:not_found)
    end
  end
end
