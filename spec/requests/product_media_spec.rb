require "rails_helper"

RSpec.describe "Product media presentation", type: :request do
  before do
    ContentBlock.sync!
    with_bunny_cdn
    allow(PaddlePriceCatalogService).to receive(:call).and_return([])
    @product = create_product(kind: :audio_process, trailer_cdn_path: "/audioprocesy/intro.mp4")
    @product.trailer_poster.attach(io: File.open(Rails.root.join("spec/fixtures/files/photo.png")), filename: "poster.png",
                                  content_type: "image/png", metadata: { trailer_cdn_path: @product.trailer_cdn_path })
  end

  it "serves the real poster through the app without preloading the CDN film" do
    get catalogue_product_path(@product)
    video = Nokogiri::HTML(response.body).at_css("video")
    expect(video["poster"]).to start_with("/rails/active_storage/blobs/proxy/")
    expect(video["preload"]).to eq("none")
    expect(video["autoplay"]).to be_nil
    expect(video["src"]).to eq(trailer_audio_process_path(slug: @product.slug))
    expect(video["aria-label"]).to include(@product.name)
    get video["poster"]
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/png")
  end

  it "does not reuse an unrelated poster after a trailer path changes" do
    @product.update_column(:trailer_cdn_path, "/audioprocesy/replacement.mp4")
    get catalogue_product_path(@product)
    expect(Nokogiri::HTML(response.body).at_css("video")["poster"]).to be_nil
  end

  it "keeps editable localized playback recovery beside the player" do
    get catalogue_product_path(@product, locale: :en)
    expect(response.body).to include("The recording could not be played", "Try playing again")
    expect(Nokogiri::HTML(response.body).at_css('[data-media-preview-target="recovery"]')["hidden"]).not_to be_nil
  end
end
