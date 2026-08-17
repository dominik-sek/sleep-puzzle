require 'rails_helper'

RSpec.describe "Products", type: :request do
  describe "GET /products" do
    it "lists the published products with their Paddle price" do
      allow(PaddlePriceCatalogService).to receive(:call)
        .and_return([ paddle_price(id: "pri_456", amount: "2500", currency: "PLN") ])
      create_product(name: "Bajka o sowie")

      get products_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bajka o sowie")
      expect(response.body).to include("25,00 PLN")
      expect(response.body).to include("Dodaj do koszyka")
    end

    it "does not list an unpublished product" do
      create_product(name: "Szkic", published: false)

      get products_path

      expect(response.body).not_to include("Szkic")
    end

    it "renders the CMS empty state when there is nothing to sell" do
      get products_path

      expect(response.body).to include("Nagrania pojawią się tu wkrótce")
    end

    # Paddle owns the money, so an unreachable Paddle means no price — better to
    # show the product as unavailable than to offer it at a guessed number
    it "hides the add button when the price cannot be read" do
      create_product(name: "Bajka o sowie")

      get products_path

      expect(response.body).to include("Bajka o sowie")
      expect(response.body).to include("Chwilowo niedostępne")
      expect(response.body).not_to include("Dodaj do koszyka")
    end

    # the design gives each product its own emoji, on the card and in the cart
    it "shows the product's own icon" do
      create_product(name: "Bajka o sowie", icon: "🐻")

      get products_path

      expect(response.body).to include("🐻")
    end

    it "falls back to an icon for the kind when the owner has not set one" do
      create_product(name: "Bajka o sowie", kind: :bedtime_story, icon: nil)

      get products_path

      expect(response.body).to include(Product::KIND_ICONS.fetch("bedtime_story"))
    end

    # the design puts a cart pill opposite the heading; the navbar badge is also
    # on screen, and two nodes with one id would break turbo_stream.replace
    it "shows the cart pill without colliding with the navbar badge" do
      post cart_items_path, params: { product_id: create_product.id }

      get products_path

      expect(response.body.scan(%(id="cart_pill")).size).to eq(1)
      expect(response.body.scan(%(id="cart_badge")).size).to eq(1)
    end

    it "does not require signing in" do
      get products_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /products/:id" do
    it "renders the product" do
      product = create_product(name: "Bajka o sowie", description: "Kojąca opowieść.")

      get product_path(product)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bajka o sowie")
    end

    it "404s on an unpublished product rather than showing something unbuyable" do
      product = create_product(name: "Szkic", published: false)

      get product_path(product)

      expect(response).to have_http_status(:not_found)
    end
  end

  it "is reachable from the navbar, which used to be a dead link" do
    get root_path

    expect(response.body).to include(%(href="#{products_path}"))
  end
end
