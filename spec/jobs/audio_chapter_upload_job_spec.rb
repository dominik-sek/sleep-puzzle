require "rails_helper"

RSpec.describe AudioChapterUploadJob, type: :job do
  let(:chapter) { create_product(kind: :audio_process).audio_chapters.first }

  it "updates the chapter only after duration extraction and Bunny storage succeed" do
    chapter.audio_upload.attach(io: StringIO.new("audio"), filename: "new.mp3", content_type: "audio/mpeg")
    allow(MediaDurationService).to receive(:call).and_return(91)
    result = double(stored?: true, path: "/audioprocesy/new.mp3")
    allow(BunnyStorageService).to receive(:call).and_return(result)

    described_class.perform_now(chapter, chapter.audio_upload.attachment.id)

    expect(chapter.reload.cdn_path).to eq("/audioprocesy/new.mp3")
    expect(chapter.duration_seconds).to eq(91)
    expect(chapter.audio_upload).not_to be_attached
  end

  it "keeps the previous chapter file and reports an invalid replacement immediately" do
    chapter.audio_upload.attach(io: StringIO.new("broken"), filename: "broken.mp3", content_type: "audio/mpeg")
    allow(MediaDurationService).to receive(:call).and_return(nil)
    expect(BunnyStorageService).not_to receive(:call)

    described_class.perform_now(chapter, chapter.audio_upload.attachment.id)

    expect(chapter.reload.cdn_path).to be_present
    expect(chapter.upload_error).to include("długości")
    expect(chapter.audio_upload).not_to be_attached
  end
end
