require "rails_helper"

RSpec.describe "Admin product URL regeneration", type: :request do
  let!(:product) { create_product(name: "Sowa") }
  let(:admin) { User.create!(email: "owner@example.com", password: "password123", admin: true) }

  before do
    allow(PaddlePriceCatalogService).to receive(:call).and_return([])
    sign_in admin
  end

  it "previews unsaved names with collision suffixes without writing anything" do
    create_product(name: "Żółw")
    expect {
      post slug_preview_admin_product_path(product), params: {
        record: { translations: { name: { pl: "Żółw", en: "Turtle" } } }
      }, as: :json
    }.not_to change(ProductSlugHistory, :count)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq({ "slug" => "zolw-2", "path" => story_path(slug: "zolw-2") })
    expect(product.reload.slug).to eq("sowa")
    expect(product.name).to eq("Sowa")
  end

  it "saves the previewed URL alongside the changed name" do
    patch admin_product_path(product), params: {
      record: { regenerate_slug: "1", slug_preview: "nowa-sowa", translations: { name: { pl: "Nowa sowa" } } }
    }
    expect(response).to redirect_to(admin_products_path)
    expect(product.reload.slug).to eq("nowa-sowa")
    expect(product.slug_histories.pluck(:slug)).to match_array(%w[sowa nowa-sowa])
  end

  it "rejects regeneration without a matching preview and keeps the saved address" do
    patch admin_product_path(product), params: {
      record: { regenerate_slug: "1", slug_preview: "different", translations: { name: { pl: "Nowa sowa" } } }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Wygeneruj podgląd ponownie")
    expect(product.reload.slug).to eq("sowa")
    expect(product.name).to eq("Sowa")
  end

  it "does not accept preview requests from customers or signed-out visitors" do
    sign_out admin
    post slug_preview_admin_product_path(product), params: { record: { kind: "bedtime_story" } }, as: :json
    expect(response).to have_http_status(:unauthorized)
    sign_in User.create!(email: "customer@example.com", password: "password123")
    post slug_preview_admin_product_path(product), params: { record: { kind: "bedtime_story" } }, as: :json
    expect(response).to redirect_to(root_path)
    expect(product.reload.slug).to eq("sowa")
  end
end
