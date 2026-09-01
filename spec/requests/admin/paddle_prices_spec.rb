require 'rails_helper'

RSpec.describe "Admin::PaddlePrices", type: :request do
  let(:admin) { User.create!(email: "owner@example.com", password: "password123", admin: true) }

  describe "access" do
    it "redirects a signed-out visitor to sign in" do
      patch admin_paddle_prices_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects a signed-in non-admin away" do
      sign_in User.create!(email: "customer@example.com", password: "password123")

      patch admin_paddle_prices_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /admin/paddle_prices" do
    before { sign_in admin }

    it "re-reads the catalogue past the cache" do
      allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price ])

      patch admin_paddle_prices_path

      expect(PaddlePriceCatalogService).to have_received(:call).with(refresh: true)
      expect(flash[:notice]).to eq("Odświeżono ceny z Paddle (1).")
    end

    # empty is either "no active prices" or "the call failed" - the service
    # swallows the error, so neither is worth reporting as a success
    it "says so when Paddle returns nothing" do
      allow(PaddlePriceCatalogService).to receive(:call).and_return([])

      patch admin_paddle_prices_path

      expect(flash[:notice]).to include("nie zwrócił żadnych cen")
    end

    it "returns to the page it was asked from" do
      allow(PaddlePriceCatalogService).to receive(:call).and_return([])

      patch admin_paddle_prices_path, headers: { "HTTP_REFERER" => admin_products_path }

      expect(response).to redirect_to(admin_products_path)
    end

    it "falls back to the packages screen when there is no referer" do
      allow(PaddlePriceCatalogService).to receive(:call).and_return([])

      patch admin_paddle_prices_path

      expect(response).to redirect_to(admin_packages_path)
    end
  end
end
