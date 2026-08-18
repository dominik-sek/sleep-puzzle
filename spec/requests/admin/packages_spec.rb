require 'rails_helper'

RSpec.describe "Admin::Packages", type: :request do
  let(:admin) { User.create!(email: "owner@example.com", password: "password123", admin: true) }

  # overrides are merged into the record hash, e.g. package_params(translations: ...)
  def package_params(overrides = {})
    {
      record: {
        paddle_price_id: "pri_123",
        duration: "4",
        position: "1",
        published: "1",
        translations: {
          "name" => { "pl" => "Szybka ulga", "en" => "Quick relief" },
          "for_whom" => { "pl" => "Dla rodziców", "en" => "" },
          "core" => { "pl" => "Konsultacja\nPlan snu", "en" => "" },
          "extra" => { "pl" => "", "en" => "" }
        }
      }.deep_merge(overrides)
    }
  end

  describe "access" do
    it "redirects a signed-out visitor to sign in" do
      get admin_packages_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects a signed-in non-admin away" do
      sign_in User.create!(email: "customer@example.com", password: "password123")

      get admin_packages_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /admin/packages" do
    before { sign_in admin }

    it "lists packages, published or not" do
      create_package(name: "Szybka ulga")
      create_package(name: "Szkic", published: false)

      get admin_packages_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Szybka ulga", "Szkic", "Ukryty")
    end

    it "shows the price Paddle reports for the stored id" do
      create_package(name: "Szybka ulga", paddle_price_id: "pri_123")
      allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_123") ])

      get admin_packages_path

      expect(response.body).to include("249,00 PLN")
    end

    # an archived or mistyped id would otherwise look identical to a working one
    it "flags a price id Paddle no longer knows about" do
      create_package(name: "Szybka ulga", paddle_price_id: "pri_gone")
      allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_123") ])

      get admin_packages_path

      expect(response.body).to include("Nieznana cena w Paddle")
    end
  end

  describe "GET /admin/packages/new" do
    before { sign_in admin }

    it "offers the Paddle catalogue as a select" do
      allow(PaddlePriceCatalogService).to receive(:call)
        .and_return([ paddle_price(id: "pri_123", product_name: "Szybka ulga") ])

      get new_admin_package_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("pri_123", "Szybka ulga — Jednorazowo — 249,00 PLN")
    end

    it "falls back to a text field when Paddle cannot be reached" do
      get new_admin_package_path

      expect(response.body).to include("Nie udało się pobrać cen z Paddle")
    end
  end

  describe "GET /admin/packages/:id/edit" do
    before { sign_in admin }

    it "prefills each language separately, without falling back" do
      package = create_package(name: "Szybka ulga")

      get edit_admin_package_path(package)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="record-name-pl" value="Szybka ulga"')
      # the English box stays empty: prefilling it with the Polish would turn
      # "not translated" into "translated, identically" on the next save
      expect(response.body).not_to include('id="record-name-en" value="Szybka ulga"')
    end
  end

  describe "POST /admin/packages" do
    before { sign_in admin }

    it "creates a package with both languages" do
      expect { post admin_packages_path, params: package_params }.to change(Package, :count).by(1)

      package = Package.last
      expect(I18n.with_locale(:pl) { package.name }).to eq("Szybka ulga")
      expect(I18n.with_locale(:en) { package.name }).to eq("Quick relief")
      expect(package.duration).to eq(4)
      expect(package).to be_published
      expect(response).to redirect_to(admin_packages_path)
    end

    it "splits a list field into one entry per line" do
      post admin_packages_path, params: package_params

      expect(Package.last.core).to eq([ "Konsultacja", "Plan snu" ])
    end

    it "leaves an untranslated field empty rather than copying the Polish in" do
      post admin_packages_path, params: package_params

      expect(Package.last.raw_translation(:for_whom, :en)).to eq("")
    end

    it "re-renders with errors when the name is missing" do
      params = package_params(translations: { "name" => { "pl" => "", "en" => "" } })

      expect { post admin_packages_path, params: params }.not_to change(Package, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Nie udało się zapisać")
    end

    # translations is a jsonb column; permitting it wholesale would let a forged
    # form write keys the model never declared
    it "ignores translated fields the model does not declare" do
      params = package_params(translations: { "smuggled" => { "pl" => "nope" } })

      post admin_packages_path, params: params

      expect(Package.last.translations).not_to have_key("smuggled")
    end
  end

  describe "PATCH /admin/packages/:id" do
    before { sign_in admin }

    it "updates the record and keeps the untouched translations" do
      package = create_package(name: "Szybka ulga", name_en: "Quick relief")

      patch admin_package_path(package),
            params: { record: { paddle_price_id: "pri_999", position: "3", published: "0",
                                translations: { "name" => { "pl" => "Spokojne noce" } } } }

      package.reload
      expect(I18n.with_locale(:pl) { package.name }).to eq("Spokojne noce")
      expect(I18n.with_locale(:en) { package.name }).to eq("Quick relief")
      expect(package.paddle_price_id).to eq("pri_999")
      expect(package).not_to be_published
    end
  end

  describe "DELETE /admin/packages/:id" do
    before { sign_in admin }

    it "deletes a package nothing has been booked against" do
      package = create_package

      expect { delete admin_package_path(package) }.to change(Package, :count).by(-1)
      expect(flash[:notice]).to be_present
    end

    it "refuses to delete a package with bookings, and says why" do
      package = create_package
      customer = User.create!(email: "customer@example.com", password: "password123")
      Booking.create!(
        name: "Anna", email: "anna@example.com", starts_at: 3.days.from_now,
        status: :confirmed, package: package, user: customer
      )

      expect { delete admin_package_path(package) }.not_to change(Package, :count)
      expect(flash[:alert]).to be_present
    end
  end
end
