require 'rails_helper'

RSpec.describe "Packages", type: :request do
  describe "GET /packages" do
    it "renders" do
      create_package(name: "Szybka ulga")

      get packages_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /packages/:id" do
    it "renders a published package" do
      package = create_package(name: "Szybka ulga")

      get package_path(package)

      expect(response).to have_http_status(:ok)
    end

    # unpublished means "not on the site yet", so a guessed id must not reach it
    it "404s for an unpublished package" do
      package = create_package(name: "Szkic", published: false)

      get package_path(package)

      expect(response).to have_http_status(:not_found)
    end
  end
end
