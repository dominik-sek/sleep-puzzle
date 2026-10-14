require "rails_helper"
require Rails.root.join("db/migrate/20261014120000_harden_audio_process_collection")

RSpec.describe HardenAudioProcessCollection do
  let(:name) { '"Idż juz spać" - audioproces' }

  it "corrects the known offer without changing recordings, publication or purchased access" do
    product = create_product(id: 2, name: name, kind: :audio_process, expected_chapter_count: 1)
    buyer = User.create!(email: "existing-listener@example.com", password: "password123")
    order = buyer.orders.create!(status: :paid, order_items: [ OrderItem.new(product: product) ])
    chapter = product.audio_chapters.sole

    2.times { described_class.new.up }

    expect(product.reload.expected_chapter_count).to eq(24)
    expect(product).not_to be_purchase_ready
    expect(Product.published).to include(product)
    expect(product.audio_chapters.sole.id).to eq(chapter.id)
    expect(product.audio_chapters.sole.cdn_path).to eq(chapter.cdn_path)
    expect(buyer.accessible_order_items).to include(order.order_items.sole)
  end

  it "preserves a count the owner has already corrected" do
    product = create_product(id: 2, name: name, kind: :audio_process, expected_chapter_count: 12)

    described_class.new.up

    expect(product.reload.expected_chapter_count).to eq(12)
  end

  it "does not apply the count to another product merely because its ID or title matches" do
    other = create_product(id: 2, name: "Inny proces", kind: :audio_process)
    same_name = create_product(id: 3, name: name, kind: :audio_process)

    described_class.new.up

    expect(other.reload.expected_chapter_count).to eq(1)
    expect(same_name.reload.expected_chapter_count).to eq(1)
  end

  it "pluralizes stored defaults without replacing owner-written copy" do
    title = ContentBlock.create!(key: "audio_landing.hero.title", value_pl: "Audioproces", value_en: "My programs")
    empty = ContentBlock.create!(key: "audio_landing.hero.empty", value_pl: "Wróć wkrótce", value_en: "The audio process will appear here soon.")

    described_class.new.up

    expect(title.reload.value_pl).to eq("Audioprocesy")
    expect(title.value_en).to eq("My programs")
    expect(empty.reload.value_pl).to eq("Wróć wkrótce")
    expect(empty.value_en).to eq("Audio processes will appear here soon.")
  end

  it "does not restore the incorrect one-chapter declaration on rollback" do
    expect { described_class.new.down }.to raise_error(ActiveRecord::IrreversibleMigration)
  end
end
