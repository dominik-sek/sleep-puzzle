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
      post cart_items_path, params: { product_id: product.id }
      post cart_items_path, params: { product_id: create_product(name: "Audioproces", paddle_price_id: "pri_789").id }

      get cart_path

      expect(response.body).to include("Bajka o sowie")
      expect(response.body).to include("Audioproces")
      expect(response.body).to include("Przejdź do płatności")
    end
  end

  describe "a cart line" do
    it "shows the price and the category, and offers no quantity control" do
      post cart_items_path, params: { product_id: product.id }

      get cart_path

      expect(response.body).to include("25,00 PLN")
      expect(response.body).to include(product.kind_label)
      expect(response.body).not_to include(%(name="quantity"))
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

    it "answers a turbo stream request with the cart, the counters and the toggle" do
      post cart_items_path, params: { product_id: product.id },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('target="cart"')
      expect(response.body).to include('target="cart_badge"')
      expect(response.body).to include('target="cart_pill"')
      # so pressing "Dodaj" on the shop grid flips that button to "Usuń"
      expect(response.body).to include(%(target="cart_toggle_product_#{product.id}"))
      expect(response.body).to include("Usuń z koszyka")
    end

    # The product page shows three things that all read the cart - the button, the
    # link into the cart and the confirmation. Streaming only the button left the
    # other two behind until a reload, which read as them having been dropped, so
    # this asserts on the stream rather than on a fresh page load.
    it "streams the product page's whole cart cluster, not just the button" do
      post cart_items_path, params: { product_id: product.id },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include(%(target="cart_actions_product_#{product.id}"))
      expect(response.body).to include("Przejdź do koszyka")
      expect(response.body).to include("Dodano do koszyka")
    end

    it "takes them all away again on removal" do
      post cart_items_path, params: { product_id: product.id }

      delete cart_item_path(product_id: product.id),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include(%(target="cart_actions_product_#{product.id}"))
      expect(response.body).to include("Dodaj do koszyka")
      expect(response.body).not_to include("Przejdź do koszyka")
      expect(response.body).not_to include("Dodano do koszyka")
    end

    # nested regions would let one stream clobber the other depending on the order
    # turbo applied them
    it "keeps the two regions separate" do
      post cart_items_path, params: { product_id: product.id },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      toggle_region = response.body[/<turbo-stream[^>]*target="cart_toggle_product_#{product.id}".*?<\/turbo-stream>/m]

      expect(toggle_region).to be_present
      expect(toggle_region).not_to include("cart_actions_product_")
    end
  end

  # a file is either in the cart or it is not, so adding twice is not two copies
  describe "adding the same product twice" do
    it "leaves one line" do
      2.times { post cart_items_path, params: { product_id: product.id } }

      get cart_path
      # counted by the line's own link, not by the name: the "dodano do koszyka"
      # flash repeats the name on the page too
      expect(response.body.scan(%(href="#{product_path(product)}")).size).to eq(1)
    end
  end

  # the button already says "Posłuchaj w koncie", but this POST is reachable without
  # it - a stale page, a direct request - and a file bought twice is money taken
  # for nothing
  describe "adding something already owned" do
    let(:user) { User.create!(email: "customer@example.com", password: "password123") }

    before do
      user.orders.create!(status: :pending, order_items: [ OrderItem.new(product: product) ])
        .mark_paid!(transaction_id: "txn_1")
      sign_in user
    end

    it "refuses to put it in the cart" do
      post cart_items_path, params: { product_id: product.id }

      get cart_path
      expect(response.body).to include("Twój koszyk jest pusty")
    end

    it "says why" do
      post cart_items_path, params: { product_id: product.id },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include("masz już to nagranie")
    end

    # added before signing in, and this account turns out to own it
    it "keeps it out of a cart filled before signing in, and says where it went" do
      sign_out user
      post cart_items_path, params: { product_id: product.id }
      sign_in user

      get cart_path

      expect(response.body).to include("Masz już te nagrania na koncie")
      expect(response.body).to include(%(href="#{dashboard_index_path}"))
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
