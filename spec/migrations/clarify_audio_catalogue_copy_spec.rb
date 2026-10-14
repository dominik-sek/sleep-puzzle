require "rails_helper"
require Rails.root.join("db/migrate/20261014130000_clarify_audio_catalogue_copy")

RSpec.describe ClarifyAudioCatalogueCopy do
  it "shortens unchanged shipped copy without replacing owner edits" do
    block = ContentBlock.create!(key: "shop.hero.returning",
      value_pl: described_class::COPY.fetch(:pl).first, value_en: "My own account guidance")

    2.times { described_class.new.up }

    expect(block.reload.value_pl).to eq(described_class::COPY.fetch(:pl).last)
    expect(block.value_en).to eq("My own account guidance")
  end

  it "restores only unchanged replacements on rollback" do
    block = ContentBlock.create!(key: "shop.hero.returning",
      value_pl: "Nowa treść właścicielki", value_en: described_class::COPY.fetch(:en).last)

    described_class.new.down

    expect(block.reload.value_pl).to eq("Nowa treść właścicielki")
    expect(block.value_en).to eq(described_class::COPY.fetch(:en).first)
  end
end
