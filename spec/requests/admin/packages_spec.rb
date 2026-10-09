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
      expect(response.body).to include("pri_123", "Szybka ulga - Jednorazowo - 249,00 PLN")
    end

    it "falls back to a text field when Paddle cannot be reached" do
      get new_admin_package_path

      expect(response.body).to include("Nie udało się pobrać cen z Paddle")
    end
  end

  describe "GET /admin/packages/:id/edit" do
    before { sign_in admin }

    it "shows editorial guidance and warnings without blocking an old record" do
      package = create_package
      package.assign_translation(:for_whom, :pl, "a" * 221)
      package.assign_translation_list(:highlights, :pl, Array.new(6, "Długi wyróżnik"))
      package.save!
      get edit_admin_package_path(package)

      expect(response.body).to include("Na karcie", "Pełne szczegóły", "Opis ma 221 znaków", "Wpisano 6 wyróżników")
      expect(response.body).to include('id="record-highlights-en"', 'id="record-organization-pl"')
      expect(response.body).not_to include('id="record-highlights-en">Długi wyróżnik')
    end

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

  describe "POST /admin/packages/preview" do
    it "requires an admin session" do
      post preview_admin_packages_path, params: package_params
      expect(response).to redirect_to(new_user_session_path)

      sign_in User.create!(email: "reader@example.com", password: "password123")
      post preview_admin_packages_path, params: package_params
      expect(response).to redirect_to(root_path)
    end

    context "as an admin" do
      before do
        sign_in admin
        allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price ])
      end

      it "renders unsaved copy and a price using the public card and details" do
        package = create_package(name: "Zapisany pakiet")
        params = package_params(translations: {
          "highlights" => { "pl" => (1..6).map { |n| "Wyróżnik #{n}" }.join("\n") },
          "organization" => { "pl" => "Przygotowanie\n\nKontakt" }
        })

        expect { post preview_admin_packages_path, params: params }.not_to change(Package, :count)

        expect(response).to have_http_status(:ok)
        html = Nokogiri::HTML.fragment(response.body)
        expect(html.at_css("h2").text).to eq("Szybka ulga")
        expect(html.css("li").map(&:text).map(&:strip)).to include("Wyróżnik 6", "Konsultacja", "Plan snu")
        expect(html.at_css("dialog").text).to include("Przygotowanie", "Kontakt")
        expect(html.text).to include("249,00 PLN", "4 tygodnie")
        expect(html.css("a[href]")).to be_empty
        expect(html.css("button[disabled]").size).to eq(2)
        expect(package.reload.name).to eq("Zapisany pakiet")
      end

      it "previews English with Polish fallback independently for each field" do
        post preview_admin_packages_path, params: package_params.merge(preview_locale: "en")

        html = Nokogiri::HTML.fragment(response.body)
        expect(html.at_css("[lang]")["lang"]).to eq("en")
        expect(html.at_css("h2").text).to eq("Quick relief")
        expect(html.text).to include("Dla rodziców", "Konsultacja", "4 weeks")
      end

      it "keeps long copy in the details and escapes submitted markup" do
        summary = "Pełny opis " * 30
        post preview_admin_packages_path, params: package_params(translations: {
          "name" => { "pl" => '<script>alert("preview")</script>' },
          "for_whom" => { "pl" => summary }
        }).merge(preview_locale: "unknown")

        html = Nokogiri::HTML.fragment(response.body)
        expect(html.at_css("[lang]")["lang"]).to eq("pl")
        expect(html.css("script")).to be_empty
        expect(html.at_css("h2").text).to include("<script>")
        expect(html.at_css("dialog").text).to include(summary.strip)
        html.at_css("dialog").remove
        expect(html.text).not_to include(summary.strip)
      end

      it "also renders an incomplete new package without saving or validating it" do
        expect do
          post preview_admin_packages_path, params: { record: { duration: "", paddle_price_id: "" } }
        end.not_to change(Package, :count)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("package-details", "Cena chwilowo niedostępna")
      end
    end
  end

  describe "POST /admin/packages" do
    before { sign_in admin }

    it "saves highlights and organization in both languages without truncating" do
      highlights = (1..6).map { |n| "Wyróżnik #{n}" }
      post admin_packages_path, params: package_params(translations: {
        "highlights" => { "pl" => highlights.join("\n"), "en" => "Sleep plan\nDaily support" },
        "organization" => { "pl" => "Przygotowanie\n\nGodziny kontaktu", "en" => "Contact hours" }
      })

      expect(Package.last.highlights).to eq(highlights)
      expect(I18n.with_locale(:en) { Package.last.highlights }).to eq([ "Sleep plan", "Daily support" ])
      expect(Package.last.organization).to eq("Przygotowanie\n\nGodziny kontaktu")
      expect(I18n.with_locale(:en) { Package.last.organization }).to eq("Contact hours")
    end

    it "creates a package with both languages" do
      expect { post admin_packages_path, params: package_params }.to change(Package, :count).by(1)

      package = Package.last
      expect(I18n.with_locale(:pl) { package.name }).to eq("Szybka ulga")
      expect(I18n.with_locale(:en) { package.name }).to eq("Quick relief")
      expect(package.duration).to eq(4)
      expect(package).to be_published
      expect(response).to redirect_to(admin_packages_path)
    end

    it "uses the default order when the position field is cleared" do
      expect { post admin_packages_path, params: package_params(position: "") }
        .to change(Package, :count).by(1)

      expect(Package.last.position).to eq(0)
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

    it "re-renders instead of raising a database error for an empty visibility value" do
      expect { post admin_packages_path, params: package_params(published: "") }
        .not_to change(Package, :count)

      expect(response).to have_http_status(:unprocessable_content)
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

    it "uses the default order when the position field is cleared" do
      package = create_package(position: 3)

      patch admin_package_path(package), params: { record: { position: "" } }

      expect(package.reload.position).to eq(0)
      expect(response).to redirect_to(admin_packages_path)
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
