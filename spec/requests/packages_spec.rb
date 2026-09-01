require 'rails_helper'

RSpec.describe "Packages", type: :request do
  def package_with_benefits(**attributes)
    create_package(**attributes).tap do |package|
      package.assign_translation(:for_whom, :pl, "Dla rodziców niemowląt")
      package.assign_translation_list(:core, :pl, [ "1h konsultacja startowa", "Dostęp do grupy na Telegramie" ])
      package.assign_translation_list(:extra, :pl, [ "Dodatkowa konsultacja 30 min" ])
      package.save!
    end
  end

  describe "GET /packages" do
    it "renders the CMS headings from their declared defaults on an empty database" do
      expect(ContentBlock.count).to eq(0)

      get packages_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pakiety współpracy")
      expect(response.body).not_to include("brak treści")
    end

    it "renders each package with its benefits" do
      package_with_benefits(name: "Szybka ulga", duration: 4)

      get packages_path

      expect(response.body).to include("Szybka ulga")
      expect(response.body).to include("Czas trwania wsparcia: 4 tygodnie")
      expect(response.body).to include("Dla kogo", "Dla rodziców niemowląt")
      expect(response.body).to include("Co otrzymujecie", "1h konsultacja startowa", "Dostęp do grupy na Telegramie")
      expect(response.body).to include("Dodatkowo", "Dodatkowa konsultacja 30 min")
    end

    # an empty list should take its heading with it rather than leave a stub
    it "leaves out a list the owner has not filled in" do
      create_package(name: "Szybka ulga")

      get packages_path

      expect(response.body).to include("Szybka ulga")
      expect(response.body).not_to include("Co otrzymujecie")
      expect(response.body).not_to include("Dodatkowo")
    end

    it "orders packages by position and hides unpublished ones" do
      create_package(name: "Drugi", position: 2)
      create_package(name: "Pierwszy", position: 1)
      create_package(name: "Szkic", published: false)

      get packages_path

      expect(response.body.index("Pierwszy")).to be < response.body.index("Drugi")
      expect(response.body).not_to include("Szkic")
    end

    it "points each call to action at the booking form for that package" do
      allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price ])
      package = create_package(name: "Szybka ulga")

      get packages_path

      expect(response.body).to include("#{bookings_path}?package_id=#{package.id}")
    end

    it "shows the amount Paddle holds for the package" do
      allow(PaddlePriceCatalogService).to receive(:call)
        .and_return([ paddle_price(amount: "24900", currency: "PLN") ])
      create_package(name: "Szybka ulga")

      get packages_path

      expect(response.body).to include("249,00 PLN")
    end

    # A package Paddle cannot price is a package we cannot sell, so the card must
    # not send anyone into a login wall, a calendar and a form for a checkout that
    # cannot complete. Same rule the shop follows.
    it "withholds the booking button when the price cannot be read" do
      package = create_package(name: "Szybka ulga")

      get packages_path

      expect(response.body).to include("Cena chwilowo niedostępna")
      expect(response.body).not_to include("#{bookings_path}?package_id=#{package.id}")
      expect(response.body).to include(contact_path)
    end

    it "names the package in each call to action for assistive tech" do
      allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price ])
      create_package(name: "Szybka ulga")

      get packages_path

      expect(response.body).to include('aria-label="Umów konsultację - Szybka ulga"')
    end

    it "anchors each card so the home page can link straight to it" do
      package = create_package(name: "Szybka ulga")

      get packages_path

      expect(response.body).to include(%(id="package_#{package.id}"))
    end

    it "shows the CMS empty state when there is nothing to sell yet" do
      get packages_path

      expect(response.body).to include("Pakiety pojawią się tutaj wkrótce")
    end

    it "renders the English copy for a translated package" do
      package_with_benefits(name: "Szybka ulga", name_en: "Quick relief")

      get packages_path(locale: :en)

      expect(response.body).to include("Quick relief", "What you get")
      # the benefit list has no English version, so it falls back to Polish
      expect(response.body).to include("1h konsultacja startowa")
    end
  end

  # /packages/:id is gone: the catalogue carries everything a package has to say
  describe "GET /packages/:id" do
    it "has no route" do
      get "/packages/1"

      expect(response).to have_http_status(:not_found)
    end
  end
end
