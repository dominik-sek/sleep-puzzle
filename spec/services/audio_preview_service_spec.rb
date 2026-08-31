require "rails_helper"

RSpec.describe AudioPreviewService do
  after { described_class.reset_availability! }

  # A real 45-second tone, so the cut is exercised against ffmpeg rather than a
  # stub. Skipped rather than failed where ffmpeg is absent: the suite has to pass
  # on a machine that has not installed it, which is the same tolerance the
  # service itself has.
  def source_file
    file = Tempfile.new([ "source", ".mp3" ], binmode: true)
    ok = system("ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                "-f", "lavfi", "-i", "sine=frequency=440:duration=45",
                "-c:a", "libmp3lame", "-q:a", "9", file.path,
                out: File::NULL, err: File::NULL)
    skip("ffmpeg is not installed") unless ok
    file
  end

  def duration_of(path)
    out = `ffprobe -hide_banner -v error -show_entries format=duration -of default=nw=1:nk=1 #{path}`
    out.to_f
  end

  describe "with ffmpeg present" do
    before { skip("ffmpeg is not installed") unless described_class.available? }

    it "cuts the first 30 seconds off a longer recording" do
      source = source_file
      preview = described_class.call(source.path)

      expect(preview).to be_present
      expect(duration_of(preview.path)).to be_within(1).of(described_class::DURATION_SECONDS)

      preview.close!
      source.close!
    end

    it "returns the whole thing when the recording is shorter than the cut" do
      short = Tempfile.new([ "short", ".mp3" ], binmode: true)
      system("ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
             "-f", "lavfi", "-i", "sine=frequency=440:duration=8",
             "-c:a", "libmp3lame", "-q:a", "9", short.path,
             out: File::NULL, err: File::NULL)

      preview = described_class.call(short.path)

      expect(preview).to be_present
      expect(duration_of(preview.path)).to be_within(1).of(8)

      preview.close!
      short.close!
    end

    # the preview is additive: nothing about it may cost a product its sale
    it "returns nil rather than raising on a file ffmpeg cannot read" do
      junk = Tempfile.new([ "junk", ".mp3" ], binmode: true)
      junk.write("this is not audio")
      junk.flush

      expect(described_class.call(junk.path)).to be_nil

      junk.close!
    end

    it "returns nil for a path that is not there" do
      expect(described_class.call("/nope/missing.mp3")).to be_nil
    end
  end

  it "returns nil when ffmpeg is not installed" do
    allow(described_class).to receive(:available?).and_return(false)

    expect(described_class.call("/anything.mp3")).to be_nil
  end
end
