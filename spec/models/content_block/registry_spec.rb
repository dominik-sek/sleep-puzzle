require 'rails_helper'

RSpec.describe ContentBlock::Registry do
  it "flattens the yaml nesting into page.section.field keys" do
    expect(described_class.keys).to include("home.hero.title", "home.about.lead")
  end

  it "keeps every key unique" do
    expect(described_class.keys).to eq(described_class.keys.uniq)
  end

  it "exposes the tree that the admin panel renders" do
    page = described_class.pages.find { |candidate| candidate.key == "home" }

    expect(page.label).to be_present
    expect(page.sections).to all(have_attributes(label: be_present))
    # a section carries fixed fields, an owner-managed list, or both
    expect(page.sections).to all(satisfy { |s| s.fields.present? || s.collection? })
  end

  describe "collections" do
    it "keys a collection by its owning section" do
      expect(described_class.collection("home.process").full_key).to eq("home.process")
    end

    it "declares item fields and seed defaults" do
      collection = described_class.collection("home.process")

      expect(collection.fields.map(&:key)).to eq(%w[title body])
      expect(collection.default_items(:pl).size).to eq(3)
    end

    it "falls back to the default locale for item defaults" do
      expect(described_class.collection("home.stats").default_items(:en))
        .to eq([ { "text" => "20+ lat" } ])
    end

    it "is nil for a section without one" do
      expect(described_class.collection("home.hero")).to be_nil
    end

    it "rejects rich item fields, which items do not support" do
      allow(described_class).to receive(:pages).and_call_original
      expect(described_class.sections.select(&:collection?).flat_map { |s| s.collection.fields.map(&:type) })
        .to all(eq("plain"))
    end
  end

  it "links a field back to its section and page" do
    field = described_class.field("home.hero.title")

    expect(field.section.full_key).to eq("home.hero")
    expect(field.section.page.key).to eq("home")
  end

  it "declares every field as either plain or rich" do
    expect(described_class.fields.map(&:type).uniq).to all(be_in(described_class::TYPES))
  end

  it "knows whether a key is declared" do
    expect(described_class.key?("home.hero.title")).to be true
    expect(described_class.key?("home.hero.nope")).to be false
  end
end
