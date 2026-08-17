require 'rails_helper'

RSpec.describe "Locale", type: :request do
  describe "resolving the locale from the path" do
    it "serves Polish at the bare path" do
      get about_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<html lang="pl">))
    end

    it "serves English under /en" do
      get about_path(locale: :en)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<html lang="en">))
      expect(response.body).to include("Children&#39;s Sleep Consultant")
    end

    it "puts English on its own address rather than reusing the Polish one" do
      expect(about_path(locale: :en)).to eq("/en/about")
      expect(about_path).to eq("/about")
    end

    # one canonical address per page: /pl/about must not answer alongside /about
    it "does not serve the default locale under a prefix" do
      get "/pl/about"

      expect(response).to have_http_status(:not_found)
    end

    # these come from a URL, so a hand-edited one should show the Polish page
    it "falls back to Polish for a locale it does not know" do
      get root_path(locale: nil), params: { locale: "de" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<html lang="pl">))
    end

    # I18n.locale is a thread-global; a request that set it and raised would leave
    # the next request on that thread in the wrong language.
    #
    # Literal paths, not helpers: an integration session folds the last request's
    # path parameters into later helper calls, so `about_path` here would itself
    # come back as /en/about and the assertion would prove nothing.
    it "does not leak the locale into the next request" do
      get "/en/about"
      get "/about"

      expect(response.body).to include(%(<html lang="pl">))
    end
  end

  describe "carrying the language between pages" do
    it "keeps English on every link once you are on an English page" do
      get products_path(locale: :en)

      expect(response.body).to include(%(href="/en/cart"))
      expect(response.body).to include(%(href="/en/about"))
    end

    it "leaves Polish links unprefixed" do
      get products_path

      expect(response.body).to include(%(href="/cart"))
      expect(response.body).to include(%(href="/about"))
      expect(response.body).to include(%(href="/packages"))
      # the only /en addresses on a Polish page are the two switchers — desktop and
      # hamburger, both rendered and one hidden by CSS — and the hreflang tag. All
      # three are meant to point at the other language.
      expect(response.body.scan(%(href="/en/)).size).to eq(3)
    end

    # Devise is outside the locale scope, so the language rides along as a query
    # string instead — someone who switched to English stays in English to sign in
    it "carries the language onto routes that are not locale-scoped" do
      get products_path(locale: :en)

      expect(response.body).to include("/users/sign_in?locale=en")
    end
  end

  describe "the switcher" do
    it "offers the other language and marks the current one" do
      get about_path

      expect(response.body).to include(%(href="/en/about"))
      expect(response.body).to include(%(aria-current="true"))
    end

    it "switches back from English to the same page" do
      get about_path(locale: :en)

      expect(response.body).to include(%(href="/about"))
    end

    # rewriting the path would drop the buyer back on the shop index
    it "stays on the same record when switching" do
      product = create_product(name: "Bajka o sowie")

      get product_path(product)

      expect(response.body).to include(%(href="/en/products/#{product.id}"))
    end

    it "carries the query string, so a filter survives the switch" do
      get products_path(sort: "newest")

      expect(response.body).to include("/en/products?sort=newest")
    end
  end

  describe "telling search engines about both" do
    it "advertises each language with hreflang" do
      get about_path

      expect(response.body).to include(%(rel="alternate" hreflang="pl" href="/about"))
      expect(response.body).to include(%(rel="alternate" hreflang="en" href="/en/about"))
    end
  end
end
