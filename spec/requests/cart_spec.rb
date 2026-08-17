require 'rails_helper'

RSpec.describe "Cart", type: :request do
  let(:product) { create_product(name: "Bajka o sowie") }

  before do
    allow(PaddlePriceCatalogService).to receive(:call)
      .and_return([ paddle_price(id: "pri_456", amount: "2500", currency: "PLN") ])
  end

  describe "GET /cart" do
    # only checkout needs an account: Paddle is what requires a customer, and
    # walling off the cart would meet an anonymous visitor with a login form
    it "does not require signing in" do
      get cart_path

      expect(response).to have_http_status(:ok)
    end

    it "renders the CMS empty state" do
      get cart_path

      expect(response.body).to include("Twój koszyk jest pusty")
      expect(response.body).to include("Przeglądaj sklep")
    end

    it "lists what has been added, with a total" do
      post cart_items_path, params: { product_id: product.id, quantity: 2 }

      get cart_path

      expect(response.body).to include("Bajka o sowie")
      expect(response.body).to include("50,00 PLN")
      expect(response.body).to include("Przejdź do płatności")
    end
  end

  # the design shows the unit price and quantity under the name, and what the
  # line comes to on the right
  describe "a cart line" do
    it "shows the unit price, the quantity and the line total" do
      post cart_items_path, params: { product_id: product.id, quantity: 3 }

      get cart_path

      expect(response.body).to include("25,00 PLN")
      expect(response.body).to include("75,00 PLN")
      expect(response.body).to include(%(value="3"))
    end

    it "shows the product's icon" do
      product.update!(icon: "🐻")
      post cart_items_path, params: { product_id: product.id }

      get cart_path

      expect(response.body).to include("🐻")
    end
  end

  describe "POST /cart_items" do
    it "adds a product and shows it in the badge count" do
      post cart_items_path, params: { product_id: product.id }

      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).to include("Bajka o sowie")
    end

    it "refuses an unpublished product" do
      hidden = create_product(name: "Szkic", published: false)

      post cart_items_path, params: { product_id: hidden.id }

      expect(response).to have_http_status(:not_found)
    end

    it "answers a turbo stream request with the cart and the badge" do
      post cart_items_path, params: { product_id: product.id },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('target="cart"')
      expect(response.body).to include('target="cart_badge"')
    end
  end

  describe "PATCH /cart_items/:product_id" do
    before { post cart_items_path, params: { product_id: product.id } }

    it "changes the quantity" do
      patch cart_item_path(product_id: product.id), params: { quantity: 4 }

      get cart_path
      expect(response.body).to include("100,00 PLN")
    end

    # what the number input produces when the buyer clears it
    it "treats zero as a removal rather than an error" do
      patch cart_item_path(product_id: product.id), params: { quantity: 0 }

      get cart_path
      expect(response.body).to include("Twój koszyk jest pusty")
    end
  end

  describe "DELETE /cart_items/:product_id" do
    it "removes the line" do
      post cart_items_path, params: { product_id: product.id }

      delete cart_item_path(product_id: product.id)

      get cart_path
      expect(response.body).to include("Twój koszyk jest pusty")
    end
  end

  describe "DELETE /cart/clear" do
    it "empties the whole cart" do
      post cart_items_path, params: { product_id: product.id }

      delete clear_cart_path

      get cart_path
      expect(response.body).to include("Twój koszyk jest pusty")
    end
  end

  # the session outlives sign-in, which is what lets checkout ask for an account
  # only at the end without costing the buyer the basket they filled
  it "keeps the cart across signing in" do
    user = User.create!(email: "customer@example.com", password: "password123")
    post cart_items_path, params: { product_id: product.id }

    sign_in user
    get cart_path

    expect(response.body).to include("Bajka o sowie")
  end
end
