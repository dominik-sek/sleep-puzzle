require "rails_helper"
require Rails.root.join("db/migrate/20261015100000_add_slugs_to_products")

RSpec.describe AddSlugsToProducts do
  it "backfills all products in ID order, including drafts, using stored names and unique suffixes" do
    first = create_product(name: "Żółw", published: false)
    duplicate = create_product(name: "Żółw", kind: :audio_process)
    english = create_product(name: "Temporary")
    empty = create_product(name: "Another temporary")
    english.update_columns(translations: { "name" => { "en" => "Sleepy Owl" } })
    empty.update_columns(translations: {})
    Product.update_all("slug = 'legacy-' || id::text")

    I18n.with_locale(:en) { described_class.new.backfill_slugs }

    expect([ first, duplicate, english, empty ].map { |product| product.reload.slug })
      .to eq(%w[zolw zolw-2 sleepy-owl product])
  end
end
