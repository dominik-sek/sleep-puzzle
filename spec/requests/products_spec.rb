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

    # the double-charge: pending means the card is charged and the webhook has
    # not landed, and the grid used to keep offering to sell it
    it "offers no add button for a product a pending order already covers" do
      allow(PaddlePriceCatalogService).to receive(:call)
        .and_return([ paddle_price(id: "pri_456", amount: "2500", currency: "PLN") ])
      product = create_product(name: "Bajka o sowie")
      user = User.create!(email: "customer@example.com", password: "password123")
      user.orders.create!(status: :pending, order_items: [ OrderItem.new(product: product) ])
      sign_in user

      get products_path

      expect(response.body).to include("Płatność w trakcie")
      expect(response.body).not_to include("Dodaj do koszyka")
    end

    it "offers the add button again once that order is released" do
      allow(PaddlePriceCatalogService).to receive(:call)
        .and_return([ paddle_price(id: "pri_456", amount: "2500", currency: "PLN") ])
      product = create_product(name: "Bajka o sowie")
      user = User.create!(email: "customer@example.com", password: "password123")
      order = user.orders.create!(status: :pending, order_items: [ OrderItem.new(product: product) ])
      order.fail_payment!(:canceled)
      sign_in user

      get products_path

      expect(response.body).to include("Dodaj do koszyka")
    end

    it "does not list an unpublished product" do
      create_product(name: "Szkic", published: false)

      get products_path

      expect(response.body).not_to include("Szkic")
    end

    # a lone card used to stretch across the full grid width
    it "caps the grid when there are too few cards to fill a row" do
      create_product(name: "Jedyny")

      get products_path

      expect(response.body).to include("sm:max-w-[320px]")
    end

    it "leaves the grid uncapped once a row fills on its own" do
      4.times { |i| create_product(name: "Nagranie #{i}") }

      get products_path

      expect(response.body).not_to include("sm:max-w-[320px]")
    end

    it "renders the CMS empty state when there is nothing to sell" do
      get products_path

      expect(response.body).to include("Nagrania pojawią się tu wkrótce")
    end

    # Paddle owns the money, so an unreachable Paddle means no price - better to
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

    # bought already, and a digital file is bought once - the card leads to where
    # it is rather than offering to sell it again
    it "shows an account link instead of an add button for something owned" do
      allow(PaddlePriceCatalogService).to receive(:call)
        .and_return([ paddle_price(id: "pri_456", amount: "2500", currency: "PLN") ])
      user = User.create!(email: "customer@example.com", password: "password123")
      owned = create_product(name: "Bajka o sowie")
      user.orders.create!(status: :pending, order_items: [ OrderItem.new(product: owned) ])
        .mark_paid!(transaction_id: "txn_1")
      sign_in user

      get products_path

      expect(response.body).to include("Posłuchaj w koncie")
      expect(response.body).to include(%(href="#{dashboard_index_path}"))
      expect(response.body).not_to include("Dodaj do koszyka")
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
      expect(response.body).to include("Odsłuch online, bez pobierania")
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

        # scoped to the section rather than counting the name across the whole
        # page: the product legitimately names itself in the heading and again in
        # <title>, so a body-wide count measures the wrong thing
        also = response.body[/Inne materiały.*/m]
        expect(also).to include("Inny")
        expect(also).not_to include("Główny")
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

  # The gate on the audio itself. The pull zone serves anyone holding a signed
  # URL, so this action is the only thing deciding who gets one.
  describe "GET /products/:id/stream" do
    let(:user) { User.create!(email: "customer@example.com", password: "password123") }
    let(:product) { create_product(name: "Bajka o sowie", cdn_path: "/bajki/o-sowie.mp3") }

    def buy(item, buyer: user)
      order = buyer.orders.create!(status: :pending, order_items: [ OrderItem.new(product: item) ])
      order.mark_paid!(transaction_id: "txn_#{order.id}")
    end

    before { with_bunny_cdn }

    it "redirects a buyer to a signed CDN URL" do
      buy(product)
      sign_in user

      get stream_product_path(product)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to start_with("https://#{BunnyHelpers::HOST}/bajki/o-sowie.mp3?token=HS256-")
      expect(response.location).to include("expires=")
    end

    it "sends a signed-out visitor to sign in" do
      get stream_product_path(product)

      expect(response).to redirect_to(new_user_session_path)
    end

    # 403 rather than 404: the shop lists the product, so its existence is not the
    # secret - the recording behind it is
    it "refuses someone who has not bought it" do
      sign_in user

      get stream_product_path(product)

      expect(response).to have_http_status(:forbidden)
    end

    # a cart that was never paid for is not a purchase, and this is the last place
    # that distinction can still be enforced
    it "refuses an unpaid order" do
      user.orders.create!(status: :pending, order_items: [ OrderItem.new(product: product) ])
      sign_in user

      get stream_product_path(product)

      expect(response).to have_http_status(:forbidden)
    end

    it "refuses a buyer of a different product" do
      buy(create_product(name: "Coś innego", paddle_price_id: "pri_999"))
      sign_in user

      get stream_product_path(product)

      expect(response).to have_http_status(:forbidden)
    end

    it "does not hand one buyer's purchase to another account" do
      buy(product, buyer: User.create!(email: "other@example.com", password: "password123"))
      sign_in user

      get stream_product_path(product)

      expect(response).to have_http_status(:forbidden)
    end

    it "404s on an unpublished product, the same as its page" do
      unpublished = create_product(name: "Szkic", published: false, cdn_path: "/szkic.mp3")
      buy(unpublished)
      sign_in user

      get stream_product_path(unpublished)

      expect(response).to have_http_status(:not_found)
    end

    # The panel cannot produce this any more - publishing requires a file - so
    # this is the defence-in-depth case: a row that lost its path some other way
    # must still not hand out a signed URL.
    it "404s when the product has no file uploaded yet" do
      fileless = create_product(name: "Bez pliku", paddle_price_id: "pri_888")
      fileless.update_column(:cdn_path, nil)
      buy(fileless)
      sign_in user

      get stream_product_path(fileless)

      expect(response).to have_http_status(:not_found)
    end

    # a deploy that lost the credentials must not redirect to an unsigned URL,
    # which the pull zone would refuse anyway
    it "404s when the CDN is unconfigured" do
      allow(BunnySignedUrlService).to receive_messages(token: nil, host: nil)
      buy(product)
      sign_in user

      get stream_product_path(product)

      expect(response).to have_http_status(:not_found)
    end
  end

  # The sample exists so someone who has bought nothing can hear the voice they
  # are being asked to pay for, so the route is deliberately open. What it must
  # never do is sign the full recording's path.
  describe "GET /products/:id/preview" do
    let(:product) { create_product(name: "Bajka", cdn_path: "/bajki/pelne.mp3") }

    it "404s when the product has no preview" do
      get preview_product_path(product)

      expect(response).to have_http_status(:not_found)
    end

    it "404s when the CDN is unconfigured, rather than offering a broken player" do
      product.update_column(:preview_cdn_path, "/bajki/probka.mp3")
      allow(BunnySignedUrlService).to receive(:configured?).and_return(false)

      get preview_product_path(product)

      expect(response).to have_http_status(:not_found)
    end

    it "redirects a signed-out visitor to a URL signed for the preview path only" do
      product.update_column(:preview_cdn_path, "/bajki/probka.mp3")
      allow(BunnySignedUrlService).to receive(:configured?).and_return(true)
      allow(BunnySignedUrlService).to receive(:call)
        .with("/bajki/probka.mp3", expires_in: ProductsController::PREVIEW_TTL)
        .and_return("https://cdn.example/bajki/probka.mp3?token=abc")

      get preview_product_path(product)

      expect(response).to redirect_to("https://cdn.example/bajki/probka.mp3?token=abc")
      expect(response.headers["Location"]).not_to include("pelne")
    end

    it "404s for an unpublished product" do
      product.update_columns(preview_cdn_path: "/bajki/probka.mp3", published: false)

      get preview_product_path(product)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the preview player on the product page" do
    before { allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456") ]) }

    it "is absent when the product has no preview" do
      get product_path(create_product(name: "Bajka"))

      expect(response.body).not_to include("Posłuchaj 30 sekund")
    end

    it "is offered when there is one" do
      product = create_product(name: "Bajka")
      product.update_column(:preview_cdn_path, "/bajki/probka.mp3")
      allow(BunnySignedUrlService).to receive(:configured?).and_return(true)

      get product_path(product)

      expect(response.body).to include("Posłuchaj 30 sekund")
      expect(response.body).to include(preview_product_path(product))
    end

    # an owner already has the whole recording in the dashboard; a sample of it
    # is a smaller offer than the one they have already taken
    it "is withheld from someone who already owns the recording" do
      product = create_product(name: "Bajka")
      product.update_column(:preview_cdn_path, "/bajki/probka.mp3")
      allow(BunnySignedUrlService).to receive(:configured?).and_return(true)
      user = User.create!(email: "buyer@example.com", password: "password123")
      allow_any_instance_of(User).to receive(:purchased?).with(product).and_return(true)
      sign_in user

      get product_path(product)

      expect(response.body).not_to include("Posłuchaj 30 sekund")
    end
  end
end
