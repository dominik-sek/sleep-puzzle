require "rails_helper"

RSpec.describe "Audio process chapters", type: :request do
  let(:product) { create_product(name: "Spokojny sen", kind: :audio_process, cdn_path: "/audioprocesy/intro.mp3") }
  let(:user) { User.create!(email: "buyer@example.com", password: "password123") }

  def buy!(buyer = user)
    order = buyer.orders.create!(status: :pending, order_items: [ OrderItem.new(product: product) ])
    order.mark_paid!(transaction_id: "txn_#{order.id}")
  end

  it "shows chapter titles and durations publicly without audio URLs" do
    chapter = product.audio_chapters.first
    chapter.update!(duration_seconds: 83)

    get audio_process_path
    expect(response.body).to include("Nagranie", "1:23")
    expect(response.body).not_to include(stream_chapter_product_path(product, chapter_id: chapter.id))

    get product_path(product)
    expect(response.body).to include("Nagranie", "1:23")
    expect(response.body).not_to include(stream_chapter_product_path(product, chapter_id: chapter.id))
  end

  it "serves the public trailer through a signed URL but never the audio preview" do
    product.update_columns(trailer_cdn_path: "/audioprocesy/trailer.mp4", preview_cdn_path: "/audioprocesy/preview.mp3")
    with_bunny_cdn

    get trailer_product_path(product)
    expect(response).to have_http_status(:redirect)
    expect(response.location).to include("/audioprocesy/trailer.mp4?token=")

    get preview_product_path(product)
    expect(response).to have_http_status(:not_found)

    get product_path(product)
    expect(response.body).to include(trailer_product_path(product))
    expect(response.body).not_to include(preview_product_path(product))

    get audio_process_path
    expect(response.body).to include(trailer_product_path(product))
  end

  it "gates every chapter on the product purchase, including one added later" do
    chapter = product.audio_chapters.first
    with_bunny_cdn
    sign_in user

    get stream_chapter_product_path(product, chapter_id: chapter.id)
    expect(response).to have_http_status(:forbidden)

    buy!
    later = product.audio_chapters.create!(position: 1, cdn_path: "/audioprocesy/later.mp3", duration_seconds: 44,
                                           translations: { "title" => { "pl" => "Później" } })
    get stream_chapter_product_path(product, chapter_id: later.id)
    expect(response).to have_http_status(:redirect)
    expect(response.location).to include("/audioprocesy/later.mp3?token=")

    get dashboard_index_path
    expect(response.body).to include("Później", stream_chapter_product_path(product, chapter_id: later.id))
    expect(response.body).to include('data-controller="chapter-playlist"')
  end

  it "does not grant a chapter of a different product" do
    other = create_product(kind: :audio_process, cdn_path: "/audioprocesy/other.mp3")
    buy!
    sign_in user

    get stream_chapter_product_path(other, chapter_id: other.audio_chapters.first.id)
    expect(response).to have_http_status(:forbidden)
  end

  it "keeps bought chapters playable if the product is later hidden from the shop" do
    chapter = product.audio_chapters.first
    buy!
    sign_in user
    with_bunny_cdn
    product.update!(published: false)

    get stream_chapter_product_path(product, chapter_id: chapter.id)
    expect(response).to have_http_status(:redirect)
  end
end
