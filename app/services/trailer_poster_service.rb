# A small, first-party still from the actual trailer, prepared before the upload
# source is purged. Failure is additive: it must not reject a playable film.
class TrailerPosterService < ApplicationService
  def initialize(source_path)
    @source_path = source_path
  end

  def call
    output = Tempfile.new([ "trailer-poster", ".jpg" ], binmode: true)
    ok = Timeout.timeout(30.seconds) do
      system("ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
             "-i", @source_path.to_s, "-vf", "thumbnail=30,scale='min(960,iw)':-2",
             "-frames:v", "1", "-q:v", "3", output.path,
             out: File::NULL, err: File::NULL)
    end
    if ok && File.size?(output.path)
      output.rewind
      return output
    end

    output.close!
    nil
  rescue Timeout::Error, Errno::ENOENT
    output&.close!
    nil
  end
end
