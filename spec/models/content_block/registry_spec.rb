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
    expect(page.sections).to all(have_attributes(label: be_present, fields: be_present))
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
