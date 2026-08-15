require 'rails_helper'

# == Schema Information
#
# Table name: content_blocks
#
#  id         :bigint           not null, primary key
#  key        :string           not null
#  value_en   :text
#  value_pl   :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_content_blocks_on_key  (key) UNIQUE
#
RSpec.describe ContentBlock, type: :model do
  let(:plain_key) { "home.hero.title" }
  let(:rich_key) { "home.about.lead" }

  describe "keys" do
    it "rejects a key that is not declared in the registry" do
      block = ContentBlock.new(key: "home.hero.nope")

      expect(block).not_to be_valid
      expect(block.errors[:key].join).to match(/content_blocks.yml/)
    end

    it "rejects a duplicate key" do
      ContentBlock.create!(key: plain_key)

      expect(ContentBlock.new(key: plain_key)).not_to be_valid
    end
  end

  describe ".sync!" do
    it "creates a row per declared field and is safe to re-run" do
      expect { ContentBlock.sync! }
        .to change(ContentBlock, :count).from(0).to(ContentBlock::Registry.keys.size)
      expect { ContentBlock.sync! }.not_to change(ContentBlock, :count)
    end

    it "leaves existing content untouched" do
      ContentBlock.create!(key: plain_key, value_pl: "zachowane")

      ContentBlock.sync!

      expect(ContentBlock.find_by(key: plain_key).value_pl).to eq("zachowane")
    end
  end

  describe ".undeclared" do
    it "finds rows whose key has been removed from the yaml" do
      ContentBlock.sync!
      ContentBlock.find_by(key: plain_key).update_column(:key, "gone.section.field")

      expect(ContentBlock.undeclared.pluck(:key)).to eq([ "gone.section.field" ])
    end
  end

  describe "plain fields" do
    it "stores the value in a column rather than Action Text" do
      block = ContentBlock.create!(key: plain_key, value_pl: "Tytuł")

      expect(block).not_to be_rich
      expect(block.value_for(:pl)).to eq("Tytuł")
      expect(ActionText::RichText.where(record: block)).to be_empty
    end
  end

  describe "rich fields" do
    it "stores both languages as separate rich texts on one row" do
      block = ContentBlock.create!(key: rich_key, body_pl: "<div>polski</div>", body_en: "<div>english</div>")

      expect(block).to be_rich
      expect(ActionText::RichText.where(record: block).pluck(:name)).to match_array(%w[body_pl body_en])
    end
  end

  describe "#value_for" do
    it "returns the requested locale when it is filled in" do
      block = ContentBlock.create!(key: plain_key, value_pl: "polski", value_en: "english")

      expect(block.value_for(:en)).to eq("english")
    end

    it "falls back to the default locale when the translation is empty" do
      block = ContentBlock.create!(key: plain_key, value_pl: "polski")

      expect(block.value_for(:en)).to eq("polski")
    end

    it "falls back for rich fields too" do
      block = ContentBlock.create!(key: rich_key, body_pl: "<div>polski</div>")

      expect(block.value_for(:en).body.to_html).to include("polski")
    end

    it "is nil when neither language has anything" do
      expect(ContentBlock.create!(key: plain_key).value_for(:pl)).to be_nil
    end

    it "ignores a locale the model does not carry" do
      block = ContentBlock.create!(key: plain_key, value_pl: "polski")

      expect(block.value_for(:de)).to eq("polski")
    end
  end

  describe "#translated?" do
    it "reports each locale separately" do
      block = ContentBlock.create!(key: plain_key, value_pl: "polski")

      expect(block.translated?(:pl)).to be true
      expect(block.translated?(:en)).to be false
    end
  end

  describe "#label" do
    it "reads the human name from the registry" do
      expect(ContentBlock.new(key: plain_key).label).to eq("Nagłówek")
    end
  end
end
