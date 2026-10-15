require "rails_helper"

RSpec.describe "Product media recovery", type: :system do
  it "keeps media idle until play, and offers a keyboard retry after a failed trailer" do
    ContentBlock.sync!
    with_bunny_cdn
    allow(PaddlePriceCatalogService).to receive(:call).and_return([])
    product = create_product(kind: :audio_process, trailer_cdn_path: "/missing-intro.mp4")
    product.trailer_poster.attach(io: File.open(Rails.root.join("spec/fixtures/files/photo.png")), filename: "poster.png",
                                 content_type: "image/png", metadata: { trailer_cdn_path: product.trailer_cdn_path, duration_seconds: 94 })
    allow(BunnySignedUrlService).to receive(:call).with(product.trailer_cdn_path).and_return("/audioprocesses/missing/trailer")
    visit catalogue_product_path(product)
    expect(page).to have_text("Film wprowadzający · 1:34")
    expect(find("video")["poster"]).to include("/rails/active_storage/blobs/proxy/")
    expect(page.evaluate_script("document.querySelector('video').networkState")).to eq(1) # NETWORK_IDLE
    expect(page.evaluate_script("performance.getEntriesByType('resource').some(r => r.name.includes('/trailer') || r.name.includes('b-cdn.net'))")).to be(false)
    expect(page).not_to have_button("Spróbuj odtworzyć ponownie")

    find("video").send_keys(:space)
    expect(page).to have_text("Nie udało się odtworzyć nagrania")
    find("button", text: "Spróbuj odtworzyć ponownie").send_keys(:enter)
    expect(page).to have_button("Spróbuj odtworzyć ponownie")
    expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
  end

  it "plays a real MP4 through the existing deferred trailer route" do
    skip("ffmpeg is not installed") unless AudioPreviewService.available?
    ContentBlock.sync!
    with_bunny_cdn
    allow(PaddlePriceCatalogService).to receive(:call).and_return([])
    product = create_product(kind: :audio_process, trailer_cdn_path: "/intro.mp4")
    source = Tempfile.new([ "intro", ".mp4" ], binmode: true)
    begin
      ok = system("ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                  "-f", "lavfi", "-i", "color=c=black:s=160x90:d=3",
                  "-c:v", "libx264", "-pix_fmt", "yuv420p", source.path,
                  out: File::NULL, err: File::NULL)
      skip("ffmpeg could not create a test video") unless ok
      source.rewind
      blob = ActiveStorage::Blob.create_and_upload!(io: source, filename: "intro.mp4", content_type: "video/mp4")
      allow(BunnySignedUrlService).to receive(:call).with(product.trailer_cdn_path)
        .and_return(Rails.application.routes.url_helpers.rails_storage_proxy_path(blob, only_path: true))
      visit catalogue_product_path(product)
      find("video").send_keys(:space)
      Selenium::WebDriver::Wait.new(timeout: 5).until { page.evaluate_script("document.querySelector('video').currentTime > 0") }
      expect(page).not_to have_button("Spróbuj odtworzyć ponownie")
    ensure
      blob&.purge
      source.close!
    end
  end
end
