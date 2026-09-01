require 'rails_helper'

RSpec.describe "Admin::Orders", type: :request do
  let(:admin) { User.create!(email: "boss@example.com", password: "password123", admin: true) }
  let(:customer) { User.create!(email: "customer@example.com", password: "password123") }
  let(:product) { create_product(name: "Bajka o sowie") }

  def order_for(products: [ product ], user: customer, paid: false)
    order = user.orders.create!(
      status: :pending,
      order_items: products.map { |p| OrderItem.new(product: p) }
    )
    order.mark_paid!(transaction_id: "txn_#{order.id}") if paid
    order
  end

  describe "access" do
    it "turns away a signed-out visitor" do
      get admin_orders_path

      expect(response).to redirect_to(new_user_session_path)
    end

    # the panel is staff-only; access is the `admin` boolean on users
    it "turns away a signed-in customer" do
      sign_in customer

      get admin_orders_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /admin/orders" do
    before { sign_in admin }

    it "lists orders with the buyer, what they bought and the status" do
      order_for(paid: true)

      get admin_orders_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("customer@example.com")
      expect(response.body).to include("Bajka o sowie")
      expect(response.body).to include(Order.status_label("paid"))
    end

    it "names every line rather than counting them" do
      other = create_product(name: "Audioproces", paddle_price_id: "pri_789")
      order_for(products: [ product, other ])

      get admin_orders_path

      expect(response.body).to include("Bajka o sowie")
      expect(response.body).to include("Audioproces")
    end

    it "filters by status" do
      order_for(paid: true)
      order_for(products: [ create_product(name: "Nieopłacone", paddle_price_id: "pri_789") ])

      get admin_orders_path(status: "paid")

      expect(response.body).to include("Bajka o sowie")
      expect(response.body).not_to include("Nieopłacone")
    end

    it "ignores a status it does not know rather than returning nothing" do
      order_for(paid: true)

      get admin_orders_path(status: "nonsense")

      expect(response.body).to include("Bajka o sowie")
    end

    it "says so when a filter matches nothing" do
      get admin_orders_path(status: "canceled")

      expect(response.body).to include("Brak zamówień")
    end

    it "is reachable from the sidebar" do
      get admin_root_path

      expect(response.body).to include(%(href="#{admin_orders_path}"))
      expect(response.body).to include("Zamówienia")
    end
  end

  describe "GET /admin/orders/:token" do
    before { sign_in admin }

    it "shows the buyer, the lines and the Paddle transaction" do
      order = order_for(paid: true)

      get admin_order_path(order)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("customer@example.com")
      expect(response.body).to include("Bajka o sowie")
      expect(response.body).to include(order.paddle_transaction_id)
    end

    # an order stuck on "oczekuje" with no transaction id is itself the answer:
    # the webhook never landed
    it "says why there is no transaction id yet on an unpaid order" do
      order = order_for

      get admin_order_path(order)

      expect(response.body).to include("płatność nie została jeszcze potwierdzona")
    end

    it "links each line through to the product it was sold from" do
      order = order_for

      get admin_order_path(order)

      expect(response.body).to include(%(href="#{edit_admin_product_path(product)}"))
    end

    # unlike the customer-facing OrdersController#show, which is scoped to the
    # signed-in buyer - the panel exists to look at other people's orders
    it "is not scoped to the admin's own orders" do
      order = order_for(user: customer)

      get admin_order_path(order)

      expect(response).to have_http_status(:ok)
    end

    it "404s on an unknown token" do
      get admin_order_path(token: "nope")

      expect(response).to have_http_status(:not_found)
    end
  end
end
