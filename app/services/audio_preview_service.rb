# Cuts the first 30 seconds off a recording, so the shop can let someone hear a
# product before paying for it.
#
# The cut happens here rather than at play time because Bunny's token auth signs
# a path, not a byte range: any URL that would serve the first thirty seconds of
# the real file would serve all of it. A preview has to be a second object in the
# storage zone, with its own path, or it is not a preview.
#
# Always transcoded to mp3 rather than stream-copied. The upload form accepts
# seven container formats and `-c copy` only lands when the output container
# matches the input codec, so copying would work for an mp3 source and silently
# produce an unplayable file for a wav or a flac one. Thirty seconds is small
# enough that re-encoding costs nothing worth optimising.
#
# Returns nil rather than raising for anything that is not a bug: the preview is
# additive, and a product whose preview could not be made must still be sellable.
class AudioPreviewService < ApplicationService
  DURATION_SECONDS = 30

  # Generous: this runs in a job behind the upload it follows, and a slow disk on
  # a cold VPS is not a reason to lose the preview. Short enough that a hung
  # ffmpeg cannot occupy a worker indefinitely.
  TIMEOUT_SECONDS = 120

  # -vn drops any cover art the source carries: an attached image would be copied
  # into the preview as a video stream and confuse players that then treat a
  # 30-second audio file as a video.
  def self.available?
    @available = nil unless defined?(@available)
    @available = system("ffmpeg", "-version", out: File::NULL, err: File::NULL) if @available.nil?
    @available
  end

  # Lets a spec exercise both branches without installing or uninstalling ffmpeg.
  def self.reset_availability!
    remove_instance_variable(:@available) if defined?(@available)
  end

  # @param source_path [String] a readable path to the full recording
  def initialize(source_path)
    @source_path = source_path
  end

  # @return [Tempfile, nil] the cut, or nil when it could not be made. The caller
  #   owns closing it.
  def call
    return log_and_skip("ffmpeg is not installed") unless self.class.available?
    return log_and_skip("source #{@source_path} is not readable") unless File.readable?(@source_path.to_s)

    cut
  end

  private

  def cut
    output = Tempfile.new([ "preview", ".mp3" ], binmode: true)

    ok = Timeout.timeout(TIMEOUT_SECONDS) do
      system("ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
             "-i", @source_path.to_s,
             "-t", DURATION_SECONDS.to_s,
             "-vn", "-c:a", "libmp3lame", "-q:a", "5",
             output.path,
             out: File::NULL, err: File::NULL)
    end

    return discard(output, "ffmpeg refused #{@source_path}") unless ok

    output.rewind
    return discard(output, "ffmpeg produced an empty preview for #{@source_path}") if output.size.zero?

    output
  rescue Timeout::Error
    discard(output, "ffmpeg timed out after #{TIMEOUT_SECONDS}s on #{@source_path}")
  end

  def discard(output, message)
    output&.close!
    log_and_skip(message)
  end

  def log_and_skip(message)
    Rails.logger.warn("Audio preview skipped: #{message}")

    nil
  end
end
