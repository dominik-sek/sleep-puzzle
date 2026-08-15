require 'rails_helper'

RSpec.describe ContentItem, type: :model do
  let(:collection_key) { "home.process" }

  it "rejects a collection that is not declared" do
    item = ContentItem.new(collection_key: "home.hero")

    expect(item).not_to be_valid
    expect(item.errors[:collection_key].join).to match(/content_blocks.yml/)
  end

  it "accepts a declared collection" do
    expect(ContentItem.new(collection_key: collection_key)).to be_valid
  end

  describe "values" do
    it "stores each field per locale" do
      item = ContentItem.new(collection_key: collection_key)
      item.assign_value("title", :pl, "Krok")
      item.assign_value("title", :en, "Step")
      item.save!

      expect(item.reload.value_for("title", :pl)).to eq("Krok")
      expect(item.value_for("title", :en)).to eq("Step")
    end

    it "falls back to the default locale" do
      item = ContentItem.create!(collection_key: collection_key)
      item.assign_value("title", :pl, "Krok")
      item.save!

      expect(item.value_for("title", :en)).to eq("Krok")
    end

    it "is nil when nothing is set" do
      expect(ContentItem.create!(collection_key: collection_key).value_for("title", :pl)).to be_nil
    end

    it "marks the record dirty rather than mutating the hash in place" do
      item = ContentItem.create!(collection_key: collection_key)
      item.assign_value("title", :pl, "Krok")

      expect(item.changes).to have_key("values")
    end

    it "renders a whole item as declared field => value" do
      item = ContentItem.create!(collection_key: collection_key)
      item.assign_value("title", :pl, "Krok")
      item.save!

      expect(item.to_values(:pl)).to eq({ "title" => "Krok", "body" => nil })
    end
  end

  describe ".sync!" do
    it "materialises the declared defaults as editable rows" do
      expect { ContentItem.sync! }.to change(ContentItem, :count).by(4) # 3 steps + 1 stat

      steps = ContentItem.for_collection("home.process")
      expect(steps.map { |i| i.value_for("title", :pl) }).to eq([ "Krok pierwszy", "Krok drugi", "Krok trzeci" ])
      expect(steps.pluck(:position)).to eq([ 1, 2, 3 ])
    end

    it "is safe to re-run" do
      ContentItem.sync!

      expect { ContentItem.sync! }.not_to change(ContentItem, :count)
    end

    it "never overwrites a list the owner already has" do
      mine = ContentItem.create!(collection_key: "home.process", position: 1)
      mine.assign_value("title", :pl, "Mój krok")
      mine.save!

      ContentItem.sync!

      expect(ContentItem.for_collection("home.process").map { |i| i.value_for("title", :pl) }).to eq([ "Mój krok" ])
    end
  end

  describe ".for_collection" do
    it "returns items in position order" do
      second = ContentItem.create!(collection_key: collection_key, position: 2)
      first = ContentItem.create!(collection_key: collection_key, position: 1)

      expect(ContentItem.for_collection(collection_key)).to eq([ first, second ])
    end

    it "ignores items of other collections" do
      ContentItem.create!(collection_key: "home.stats")

      expect(ContentItem.for_collection(collection_key)).to be_empty
    end
  end
end
