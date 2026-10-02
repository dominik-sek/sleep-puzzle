require "open3"

class MediaDurationService
  def self.call(path)
    output, status = Timeout.timeout(30) do
      Open3.capture2("ffprobe", "-v", "error", "-show_entries", "format=duration",
                     "-of", "default=noprint_wrappers=1:nokey=1", path.to_s)
    end
    return unless status.success?

    seconds = Float(output).round
    seconds if seconds.positive?
  rescue ArgumentError, Errno::ENOENT, Timeout::Error
    nil
  end
end
