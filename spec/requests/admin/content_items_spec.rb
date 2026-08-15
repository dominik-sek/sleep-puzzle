require 'rails_helper'

RSpec.describe "Admin::ContentItems", type: :request do
  let(:admin) { User.create!(email: "owner@example.com", password: "password123", admin: true) }
  let(:customer) { User.create!(email: "customer@example.com", password: "password123") }

  before { ContentBlock.sync! }

  it "is closed to non-admins" do
    sign_in customer

    expect {
      post admin_content_items_path, params: { collection_key: "home.process" }
    }.not_to change(ContentItem, :count)

    expect(response).to redirect_to(root_path)
  end

  describe "POST /admin/content_items" do
    before { sign_in admin }

    it "appends an empty item to the collection" do
      expect {
        post admin_content_items_path, params: { collection_key: "home.process" }
      }.to change(ContentItem, :count).by(1)

      expect(ContentItem.last.collection_key).to eq("home.process")
      expect(response).to redirect_to(admin_content_blocks_path(open: "home.process"))
    end

    it "positions each new item after the last" do
      3.times { post admin_content_items_path, params: { collection_key: "home.process" } }

      expect(ContentItem.for_collection("home.process").pluck(:position)).to eq([ 1, 2, 3 ])
    end

    it "404s for a section that has no collection" do
      post admin_content_items_path, params: { collection_key: "home.hero" }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /admin/content_items/:id" do
    before { sign_in admin }

    it "removes the item" do
      item = ContentItem.create!(collection_key: "home.process", position: 1)

      expect { delete admin_content_item_path(item) }.to change(ContentItem, :count).by(-1)
      expect(response).to redirect_to(admin_content_blocks_path(open: "home.process"))
    end
  end

  describe "saving item values through the section form" do
    before { sign_in admin }

    it "writes each declared field in both languages" do
      item = ContentItem.create!(collection_key: "home.process", position: 1)

      patch admin_content_blocks_path, params: {
        section: "home.process",
        items: { item.id.to_s => { position: "2", values: { title: { pl: "Krok", en: "Step" }, body: { pl: "Opis" } } } }
      }

      item.reload
      expect(item.position).to eq(2)
      expect(item.value_for("title", :pl)).to eq("Krok")
      expect(item.value_for("title", :en)).to eq("Step")
      expect(item.value_for("body", :pl)).to eq("Opis")
    end

    it "ignores fields that are not declared on the collection" do
      item = ContentItem.create!(collection_key: "home.process", position: 1)

      patch admin_content_blocks_path, params: {
        section: "home.process",
        items: { item.id.to_s => { values: { title: { pl: "Krok" }, smuggled: { pl: "nie" } } } }
      }

      expect(item.reload.values.keys).to eq([ "title" ])
    end

    it "does not touch items belonging to another section" do
      stat = ContentItem.create!(collection_key: "home.stats", position: 1)
      stat.assign_value("text", :pl, "20+ lat")
      stat.save!

      patch admin_content_blocks_path, params: {
        section: "home.process",
        items: { stat.id.to_s => { values: { title: { pl: "przejęte" } } } }
      }

      expect(stat.reload.value_for("text", :pl)).to eq("20+ lat")
      expect(stat.values.keys).to eq([ "text" ])
    end
  end
end
