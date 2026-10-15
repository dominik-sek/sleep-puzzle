require "rails_helper"

RSpec.describe "Product slugs", type: :model do
  it "generates a transliterated Polish slug regardless of the active locale" do
    product = I18n.with_locale(:en) { create_product(name: "Żółw, Łąka i Spokojny SEN!", name_en: "Sleepy turtle") }

    expect(product.slug).to eq("zolw-laka-i-spokojny-sen")
    expect(product.to_param).to eq(product.id.to_s)
  end

  it "falls back to the English name and then to product when names yield no slug" do
    english = build_product(name: "", name_en: "Sleepy Owl")
    english.valid?
    expect(english.slug).to eq("sleepy-owl")

    empty = build_product(name: "!!!")
    empty.valid?
    expect(empty.slug).to eq("product")
  end

  it "normalizes underscores and repeated separators to hyphens" do
    expect(create_product(name: "_Audio_process -- spokojny__sen_").slug).to eq("audio-process-spokojny-sen")
  end

  it "allocates unique numeric suffixes across both product kinds and existing suffixes" do
    first = create_product(name: "Sowa")
    reserved_suffix = create_product(name: "Sowa 2")
    duplicate = create_product(name: "Sowa", kind: :audio_process)
    another = create_product(name: "Sowa")

    expect([ first, reserved_suffix, duplicate, another ].map(&:slug)).to eq(%w[sowa sowa-2 sowa-3 sowa-4])
  end

  it "keeps the slug when either name is changed" do
    product = create_product(name: "Pierwsza nazwa")
    product.assign_translation(:name, :pl, "Nowa nazwa")
    product.assign_translation(:name, :en, "New name")
    product.save!

    expect(product.reload.slug).to eq("pierwsza-nazwa")
  end

  it "enforces unique non-null slugs in the database" do
    index = Product.connection.indexes(:products).find { |candidate| candidate.columns == [ "slug" ] }
    expect(index.unique).to be(true)
    expect(Product.columns_hash.fetch("slug").null).to be(false)
  end
end
