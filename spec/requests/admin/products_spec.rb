require 'rails_helper'

RSpec.describe "Admin::Products", type: :request do
  let(:admin) { User.create!(email: "owner@example.com", password: "password123", admin: true) }

  # overrides are merged into the record hash, e.g. product_params(kind: "audio_process")
  def product_params(overrides = {})
    {
      record: {
        paddle_price_id: "pri_456",
        kind: "bedtime_story",
        position: "1",
        published: "1",
        translations: {
          "name" => { "pl" => "Bajka o sowie", "en" => "The owl story" },
          "description" => { "pl" => "Kojąca bajka na dobranoc", "en" => "" }
        }
      }.deep_merge(overrides)
    }
  end

  describe "access" do
    it "redirects a signed-in non-admin away" do
      sign_in User.create!(email: "customer@example.com", password: "password123")

      get admin_products_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /admin/products" do
    before { sign_in admin }

    it "lists products with their kind" do
      create_product(name: "Bajka o sowie", kind: :bedtime_story)
      create_product(name: "Wieczorny rytuał", kind: :audio_process)

      get admin_products_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bajka o sowie", "Bajka na dobranoc", "Wieczorny rytuał", "Audioproces")
    end
  end

  describe "GET /admin/products/new and /edit" do
    before { sign_in admin }

    it "renders the new form" do
      get new_admin_product_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bajka na dobranoc", "Audioproces")
    end

    it "renders the edit form" do
      get edit_admin_product_path(create_product(name: "Bajka o sowie"))

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bajka o sowie")
    end
  end

  describe "POST /admin/products" do
    before { sign_in admin }

    it "creates a product with both languages" do
      expect { post admin_products_path, params: product_params }.to change(Product, :count).by(1)

      product = Product.last
      expect(I18n.with_locale(:pl) { product.name }).to eq("Bajka o sowie")
      expect(I18n.with_locale(:en) { product.name }).to eq("The owl story")
      expect(product).to be_bedtime_story
      expect(response).to redirect_to(admin_products_path)
    end

    it "re-renders with errors when the name is missing" do
      params = product_params(translations: { "name" => { "pl" => "", "en" => "" } })

      expect { post admin_products_path, params: params }.not_to change(Product, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects a kind that is not one of the two the shop sells" do
      post admin_products_path, params: product_params(kind: "podcast")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Product.count).to eq(0)
    end
  end

  describe "PATCH /admin/products/:id" do
    before { sign_in admin }

    it "updates the record" do
      product = create_product(name: "Bajka o sowie")

      patch admin_product_path(product),
            params: { record: { paddle_price_id: "pri_456", kind: "audio_process", published: "0",
                                translations: { "name" => { "en" => "Evening ritual" } } } }

      product.reload
      expect(product).to be_audio_process
      expect(I18n.with_locale(:en) { product.name }).to eq("Evening ritual")
      expect(I18n.with_locale(:pl) { product.name }).to eq("Bajka o sowie")
    end
  end

  describe "DELETE /admin/products/:id" do
    before { sign_in admin }

    it "deletes the product" do
      product = create_product

      expect { delete admin_product_path(product) }.to change(Product, :count).by(-1)
    end
  end
end
