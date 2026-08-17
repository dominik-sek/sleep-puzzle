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

    it "shows a remove button on the card of something already in the cart" do
      allow(PaddlePriceCatalogService).to receive(:call)
        .and_return([ paddle_price(id: "pri_456", amount: "2500", currency: "PLN") ])
      in_cart = create_product(name: "W koszyku")
      create_product(name: "Jeszcze nie", paddle_price_id: "pri_456")
      post cart_items_path, params: { product_id: in_cart.id }

      get products_path

      expect(response.body).to include("Usuń z koszyka")
      expect(response.body).to include("Dodaj do koszyka")
    end

    it "does not require signing in" do
      get products_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /products/:id" do
    before do
      allow(PaddlePriceCatalogService).to receive(:call)
        .and_return([ paddle_price(id: "pri_456", amount: "12900", currency: "PLN") ])
    end

    it "renders the product with its price, icon and specs" do
      product = create_product(name: "Bajka o sowie", description: "Kojąca opowieść.",
                               icon: "🐻", length_minutes: 42)

      get product_path(product)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bajka o sowie")
      expect(response.body).to include("Kojąca opowieść.")
      expect(response.body).to include("129,00 PLN")
      expect(response.body).to include("🐻")
      expect(response.body).to include("42 min")
      expect(response.body).to include("MP3 do pobrania")
      expect(response.body).to include("Bezterminowy, w Twoim koncie")
    end

    it "renders the long description and the includes bullets" do
      product = create_product(long_description: "Nagranie prowadzi Cię przez cały proces.",
                               includes: [ "7 rozdziałów audio", "Plan pierwszych 3 nocy" ])

      get product_path(product)

      expect(response.body).to include("O tym nagraniu")
      expect(response.body).to include("Nagranie prowadzi Cię przez cały proces.")
      expect(response.body).to include("Co dostajesz")
      expect(response.body).to include("7 rozdziałów audio")
      expect(response.body).to include("Plan pierwszych 3 nocy")
    end

    # a product the owner has not written up yet should render as the top half,
    # not as empty headings
    it "leaves out the sections the owner has not filled in" do
      product = create_product(long_description: nil, includes: nil, length_minutes: nil)

      get product_path(product)

      expect(response.body).not_to include("O tym nagraniu")
      expect(response.body).not_to include("Co dostajesz")
      expect(response.body).not_to include("Długość")
    end

    describe "the cart toggle" do
      it "offers only the add button while the product is not in the cart" do
        product = create_product

        get product_path(product)

        expect(response.body).to include("Dodaj do koszyka")
        expect(response.body).not_to include("Usuń z koszyka")
        expect(response.body).not_to include("Przejdź do koszyka")
        expect(response.body).not_to include("Dodano do koszyka")
      end

      # a digital file is bought once, so the second press should undo the first
      # rather than add a second copy
      it "turns into a remove button once it is in the cart" do
        product = create_product
        post cart_items_path, params: { product_id: product.id }

        get product_path(product)

        expect(response.body).to include("Usuń z koszyka")
        expect(response.body).not_to include("Dodaj do koszyka")
      end

      # the second button would otherwise point at an empty cart
      it "offers the cart link and the confirmation once it is in there" do
        product = create_product
        post cart_items_path, params: { product_id: product.id }

        get product_path(product)

        expect(response.body).to include("Przejdź do koszyka")
        expect(response.body).to include("Dodano do koszyka")
      end
    end

    describe "Inne materiały" do
      it "links up to three other published products" do
        product = create_product(name: "Główny")
        4.times { |i| create_product(name: "Inny #{i}") }

        get product_path(product)

        expect(response.body).to include("Inne materiały")
        expect(response.body.scan(/Inny \d/).size).to eq(ProductsController::ALSO_LIMIT)
      end

      it "never suggests the product being looked at" do
        product = create_product(name: "Główny")
        create_product(name: "Inny")

        get product_path(product)

        expect(response.body.scan("Główny").size).to eq(1)
      end

      it "leaves the section out when there is nothing else to show" do
        get product_path(create_product)

        expect(response.body).not_to include("Inne materiały")
      end

      it "does not suggest an unpublished product" do
        product = create_product(name: "Główny")
        create_product(name: "Szkic", published: false)

        get product_path(product)

        expect(response.body).not_to include("Szkic")
      end
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
