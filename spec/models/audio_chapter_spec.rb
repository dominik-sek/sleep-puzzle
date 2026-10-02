require "rails_helper"

RSpec.describe AudioChapter, type: :model do
  it "publishes an audio process only when a ready chapter exists and sums chapter lengths" do
    product = build_product(kind: :audio_process, published: false, cdn_path: nil)
    product.save!
    product.audio_chapters.create!(position: 0, translations: { "title" => { "pl" => "Początek" } })

    expect(product.update(published: true)).to be(false)
    expect(Product.published).not_to include(product)

    first = product.audio_chapters.first
    first.update!(cdn_path: "/audioprocesy/first.mp3", duration_seconds: 65)
    product.audio_chapters.create!(position: 1, cdn_path: "/audioprocesy/second.mp3", duration_seconds: 75,
                                   translations: { "title" => { "pl" => "Dalej" } })
    expect(product.update(published: true)).to be(true)
    expect(Product.published).to include(product)
    expect(product.length_label).to eq("3 min")
  end

  it "falls back to a Polish chapter title in English" do
    chapter = create_product(kind: :audio_process).audio_chapters.first
    chapter.assign_translation(:title, :en, "")

    expect(I18n.with_locale(:en) { chapter.title }).to eq("Nagranie")
  end
end
