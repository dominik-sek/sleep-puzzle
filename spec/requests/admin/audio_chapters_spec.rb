require "rails_helper"

RSpec.describe "Admin audio chapters", type: :request do
  let(:admin) { User.create!(email: "admin@example.com", password: "password123", admin: true) }
  let(:product) { create_product(kind: :audio_process) }

  before { sign_in admin }

  it "adds bilingual chapters and changes their order" do
    post admin_product_audio_chapters_path(product), params: {
      audio_chapter: { position: 2, translations: { title: { pl: "Oddech", en: "Breathing" } } }
    }
    chapter = product.audio_chapters.reload.last
    expect(response).to redirect_to(edit_admin_product_audio_chapter_path(product, chapter))
    expect(chapter.title).to eq("Oddech")
    expect(I18n.with_locale(:en) { chapter.title }).to eq("Breathing")

    patch admin_product_audio_chapter_path(product, chapter), params: { audio_chapter: { position: 0 } }
    expect(chapter.reload.position).to eq(0)
  end

  it "does not delete a chapter from a bought product" do
    chapter = product.audio_chapters.first
    buyer = User.create!(email: "buyer@example.com", password: "password123")
    buyer.orders.create!(status: :paid, order_items: [ OrderItem.new(product: product) ])

    expect { delete admin_product_audio_chapter_path(product, chapter) }.not_to change(AudioChapter, :count)
    expect(response).to redirect_to(edit_admin_product_path(product))
  end
end
