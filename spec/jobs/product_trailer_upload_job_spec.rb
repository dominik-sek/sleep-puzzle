require "rails_helper"

RSpec.describe ProductTrailerUploadJob, type: :job do
  it "converts an uploaded MOV to a playable MP4 before changing the public path" do
    skip("ffmpeg is not installed") unless AudioPreviewService.available?

    source = Tempfile.new([ "intro", ".mov" ], binmode: true)
    begin
      ok = system("ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                  "-f", "lavfi", "-i", "color=c=black:s=160x90:d=1",
                  "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
                  "-map", "0:v:0", "-map", "1:a:0", "-c:v", "mpeg4", "-c:a", "aac", "-shortest", source.path,
                  out: File::NULL, err: File::NULL)
      skip("ffmpeg could not create a test video") unless ok

      product = create_product(kind: :audio_process)
      source.rewind
      product.trailer_upload.attach(io: source, filename: "intro.mov", content_type: "video/quicktime")
      allow(BunnyStorageService).to receive(:call) do |file, kind:, media:, filename:|
        expect(kind).to eq(:audio_process)
        expect(media).to eq(:video)
        expect(filename).to eq("intro.mp4")
        expect(File.size(file.path)).to be > 0
        double(stored?: true, path: "/audioprocesy/intro.mp4")
      end

      described_class.perform_now(product, product.trailer_upload.attachment.id)
      expect(product.reload.trailer_cdn_path).to eq("/audioprocesy/intro.mp4")
      expect(product.trailer_upload).not_to be_attached
    ensure
      source.close!
    end
  end

  it "keeps the existing trailer when the replacement is not a video" do
    product = create_product(kind: :audio_process)
    product.update_column(:trailer_cdn_path, "/audioprocesy/old.mp4")
    product.trailer_upload.attach(io: StringIO.new("broken"), filename: "intro.mov", content_type: "video/quicktime")

    described_class.perform_now(product, product.trailer_upload.attachment.id)

    expect(product.reload.trailer_cdn_path).to eq("/audioprocesy/old.mp4")
    expect(product.trailer_upload_error).to be_present
    expect(product.trailer_upload).not_to be_attached
  end
end
