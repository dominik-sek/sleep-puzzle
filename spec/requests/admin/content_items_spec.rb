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
    before do
      sign_in admin
      ContentItem.sync!
    end

    it "appends an empty item to the collection" do
      expect {
        post admin_content_items_path, params: { collection_key: "home.process" }
      }.to change(ContentItem, :count).by(1)

      expect(ContentItem.last.collection_key).to eq("home.process")
      expect(response).to redirect_to(admin_content_blocks_path(open: "home.process"))
    end

    it "lets the admin add a FAQ question and answer" do
      get admin_content_blocks_path(open: "home.faq")

      expect(response.body).to include('id="section-home-faq"', "Dodaj: pytanie")

      post admin_content_items_path, params: { collection_key: "home.faq" }
      item = ContentItem.for_collection("home.faq").last

      expect(response).to redirect_to(admin_content_blocks_path(open: "home.faq"))
      get admin_content_blocks_path(open: "home.faq")
      expect(response.body).to include("items[#{item.id}][values][question][pl]", "items[#{item.id}][values][answer][pl]")

      patch admin_content_blocks_path, params: {
        section: "home.faq",
        items: { item.id.to_s => { values: { question: { pl: "Czy to działa?" }, answer: { pl: "Tak." } } } }
      }

      expect(item.reload.value_for("question", :pl)).to eq("Czy to działa?")
      expect(item.value_for("answer", :pl)).to eq("Tak.")
    end

    it "positions each new item after the last" do
      # 1..3 are home.process's declared defaults, materialised by sync!
      3.times { post admin_content_items_path, params: { collection_key: "home.process" } }

      expect(ContentItem.for_collection("home.process").pluck(:position)).to eq([ 1, 2, 3, 4, 5, 6 ])
    end

    # An empty collection renders from its declared defaults, so appending the
    # first row used to swap the whole list for that one blank row - the owner
    # clicked "add" and the live page lost every entry it had been showing.
    context "when the collection has never been synced" do
      before { ContentItem.for_collection("terms.clauses").delete_all }

      it "materialises the declared defaults instead of replacing them" do
        declared = ContentBlock::Registry.collection("terms.clauses").defaults.size

        expect {
          post admin_content_items_path, params: { collection_key: "terms.clauses" }
        }.to change(ContentItem, :count).by(declared + 1)
      end

      it "leaves the public page showing the clauses it showed before" do
        get terms_path
        before_count = response.body.scan(/<dt/).size

        post admin_content_items_path, params: { collection_key: "terms.clauses" }

        get terms_path
        expect(response.body.scan(/<dt/).size).to eq(before_count + 1)
      end
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

    it "rejects a malformed position without losing the section's existing content" do
      item = ContentItem.create!(collection_key: "home.process", position: 1)
      block = ContentBlock.find_by!(key: "home.process.title")
      original_title = block.value_pl

      patch admin_content_blocks_path, params: {
        section: "home.process",
        fields: { title: { pl: "Nowy tytuł" } },
        items: { item.id.to_s => { position: "abc" } }
      }

      expect(response).to redirect_to(admin_content_blocks_path(open: "home.process"))
      expect(flash[:alert]).to include("Nie udało się zapisać")
      expect(item.reload.position).to eq(1)
      expect(block.reload.value_pl).to eq(original_title)
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
