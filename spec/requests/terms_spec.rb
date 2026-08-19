require 'rails_helper'

RSpec.describe "Terms", type: :request do
  describe "GET /terms" do
    it "renders the CMS copy from its declared defaults on an empty database" do
      expect(ContentBlock.count).to eq(0)

      get terms_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Regulamin współpracy")
      expect(response.body).not_to include("brak treści")
    end

    it "lists every clause from the collection's defaults, in order" do
      get terms_path

      headings = response.body.scan(/\d+\. [^<]+/)

      expect(headings.first).to start_with("1. Postanowienia ogólne")
      expect(response.body).to include("2. Zakres usług")
      expect(response.body).to include("6. Poufność")
      expect(response.body.index("1. Postanowienia"))
        .to be < response.body.index("6. Poufność")
    end

    it "renders each clause's body alongside its heading" do
      get terms_path

      expect(response.body).to include("zasady korzystania z konsultacji")
      expect(response.body).to include("operatora płatności Paddle")
      expect(response.body).to include("nie zastępują konsultacji medycznej")
    end

    # The RODO art. 13 notice and the cookie statement. Asserted by clause rather
    # than by wording so a reworded paragraph does not fail the suite, but the
    # page is never allowed to ship without them: they are the only place the site
    # tells a visitor who the controller is and what is stored in their browser.
    it "carries the personal data and cookie clauses" do
      get terms_path

      expect(response.body).to include("7. Dane osobowe")
      expect(response.body).to include("8. Pliki cookies")
      expect(response.body).to include("Prezesa Urzędu Ochrony Danych Osobowych")
    end

    it "carries them in English too" do
      get terms_path(locale: :en)

      expect(response.body).to include("7. Personal data")
      expect(response.body).to include("8. Cookies")
    end

    # white-space: pre-line keeps newlines, so any gap the template leaves
    # between the tag and the value shows up as a blank first line of the clause
    it "leaves no whitespace between a clause body and its tag" do
      get terms_path

      expect(response.body).to match(/<dd[^>]*>Niniejszy regulamin/)
      expect(response.body).not_to match(/<dd[^>]*>\s/)
    end

    # an ERB comment ends at its first %>, so one that contains a literal ERB tag
    # spills the rest of itself onto the page as text
    it "leaks no ERB comment text onto the page" do
      get terms_path

      expect(response.body).not_to include("%>")
    end

    it "renders the English copy under the English locale" do
      get terms_path(locale: :en)

      expect(response.body).to include("Terms of cooperation")
      expect(response.body).to include("1. General provisions")
      expect(response.body).to include("Bookings and payments")
    end

    it "shows what the owner has written instead of the defaults" do
      ContentItem.create!(collection_key: "terms.clauses", position: 0,
                          values: { "heading" => { "pl" => "1. Zmienione" },
                                    "body" => { "pl" => "Treść wpisana w panelu." } })

      get terms_path

      expect(response.body).to include("Treść wpisana w panelu.")
      expect(response.body).not_to include("Postanowienia ogólne")
    end

    it "does not require signing in" do
      get terms_path

      expect(response).to have_http_status(:ok)
    end
  end

  it "is reachable from the footer, which used to be plain text" do
    get root_path

    expect(response.body).to include(%(href="#{terms_path}"))
  end

  # the tile is CMS-driven so the owner can repoint it, but it should ship
  # aimed at the page rather than at "#"
  it "is where the contact page's terms tile points by default" do
    get contact_path

    expect(response.body).to include(%(href="/terms"))
  end
end
