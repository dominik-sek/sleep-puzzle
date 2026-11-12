require 'rails_helper'

RSpec.describe "Paddle catalogue outages", type: :request do
  before do
    # Exercise the real service and SDK, rather than the request suite's default
    # empty-catalogue stub. Production receives HTML from Cloudflare on HTTP 429.
    allow(PaddlePriceCatalogService).to receive(:call).and_call_original
    connection = Faraday.new(Paddle.config.url) do |conn|
      conn.response :json
      conn.adapter :test do |stub|
        stub.get("/prices") { [ 429, { "Content-Type" => "text/html" }, "<html>Access denied</html>" ] }
      end
    end
    allow(Paddle::Client).to receive(:connection).and_return(connection)
    create_product(name: "Bajka o sowie")
    create_package(name: "Szybka ulga")
  end

  %w[/products /packages /en/products /en/packages].each do |path|
    it "keeps #{path} available" do
      get path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Szybka ulga")
    end
  end

  describe "admin" do
    before { sign_in User.create!(email: "owner@example.com", password: "password123", admin: true) }

    %w[/admin/products /admin/packages].each do |path|
      it "keeps #{path} available" do
        get path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Nieznana cena w Paddle")
      end
    end

    %w[/admin/products/new /admin/packages/new].each do |path|
      it "keeps #{path} usable with a manual price field" do
        get path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Nie udało się pobrać cen z Paddle")
        expect(Capybara.string(response.body)).to have_css('input[name="record[paddle_price_id]"]')
      end
    end

    it "reports a failed manual refresh without crashing" do
      patch admin_paddle_prices_path

      expect(response).to redirect_to(admin_packages_path)
      expect(flash[:notice]).to include("Paddle nie zwrócił żadnych cen")
    end
  end
end
