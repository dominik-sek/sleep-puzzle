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

    # I18n.locale is a thread-global; a request that set it and left it set would
    # have the next request on that thread render in the wrong language. The
    # around_action uses with_locale precisely so it unwinds.
    it "restores the thread's locale once the request is over" do
      get "/en/about"

      expect(I18n.locale).to eq(I18n.default_locale)
    end

    it "serves Polish to someone who has not chosen a language" do
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
      # the only /en addresses on a Polish page point at the other language: the
      # hreflang tag and the switcher, which renders twice — once in the desktop
      # dropdown and once in the hamburger panel, one of them hidden by CSS
      other_language_links = response.body.scan(%(href="/en/)).size
      expect(other_language_links).to eq(3)
    end

    # Devise is outside the locale scope, so the language rides along as a query
    # string instead — someone who switched to English stays in English to sign in
    it "carries the language onto routes that are not locale-scoped" do
      get products_path(locale: :en)

      expect(response.body).to include("/users/sign_in?locale=en")
    end
  end

  # The URL is the whole answer on the public site. The choice is remembered only
  # for the pages whose path cannot state it — chiefly the Google handshake, which
  # leaves the site and comes back with nothing to say which language was picked.
  describe "remembering the choice" do
    it "still serves Polish at a bare path after a visit to English" do
      get "/en/about"

      get "/packages"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<html lang="pl">))
    end

    # the switcher's Polish link is the bare path; if that were overridden by what
    # was remembered, there would be no way back
    it "lets the switcher get back to Polish" do
      get "/en/about"

      get "/about"

      expect(response.body).to include(%(<html lang="pl">))
    end

    # there is no /en/users/sign_in to send anyone to, so these follow the language
    # the public site was last showing
    it "carries the language onto a route that has no localized address" do
      get "/en/about"

      get "/users/sign_in"

      expect(response.body).to include("Log in")
      expect(response.body).not_to include("Adres e-mail")
    end

    it "and back again once the visitor returns to Polish" do
      get "/en/about"
      get "/about"

      get "/users/sign_in"

      expect(response.body).to include("Adres e-mail")
    end

    it "leaves someone who never chose on Polish" do
      get "/users/sign_in"

      expect(response.body).to include("Adres e-mail")
    end
  end

  describe "the switcher" do
    it "is a menu naming each language in itself, with a flag" do
      get about_path

      expect(response.body).to include("Polski")
      expect(response.body).to include("English")
      expect(response.body).to include("🇵🇱")
      expect(response.body).to include("🇬🇧")
    end

    it "marks the language you are on rather than linking it" do
      get about_path

      expect(response.body).to include(%(aria-current="true"))
    end

    # the trigger is shown to everyone, and one whose content never rendered opens
    # nothing — which is what happens if the panel is nested in the signed-in branch
    it "opens for a signed-out visitor too" do
      get about_path

      expect(response.body).to include(%(id="locale-content"))
      expect(response.body).to include(%(data-content-id="locale-content"))
    end

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
