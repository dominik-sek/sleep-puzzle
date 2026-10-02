require "rails_helper"
require Rails.root.join("db/migrate/20261002000000_add_audio_process_chapters_and_trailers")

RSpec.describe AddAudioProcessChaptersAndTrailers do
  it "backfills a legacy single-file audio process without changing its product or purchase" do
    product = build_product(kind: :audio_process, published: false, cdn_path: "/audioprocesy/legacy.mp3", length_minutes: 12)
    product.save!
    product.update_column(:published, true)
    buyer = User.create!(email: "legacy@example.com", password: "password123")
    buyer.orders.create!(status: :paid, order_items: [ OrderItem.new(product: product) ])

    described_class.new.backfill_legacy_audio

    chapter = product.audio_chapters.first
    expect(chapter.cdn_path).to eq("/audioprocesy/legacy.mp3")
    expect(chapter.duration_seconds).to eq(720)
    expect(Product.published).to include(product)
    expect(buyer.purchased?(product)).to be(true)
  end
end
