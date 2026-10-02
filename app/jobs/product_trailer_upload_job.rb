class ProductTrailerUploadJob < ApplicationJob
  queue_as :default

  class TransferFailed < StandardError; end
  class InvalidMedia < StandardError; end
  discard_on InvalidMedia do |job, error|
    job.give_up(error.message)
  end
  retry_on TransferFailed, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.give_up(error.message)
  end

  def perform(product, attachment_id)
    attachment = product.trailer_upload.attachment
    return unless attachment&.id == attachment_id

    output = Tempfile.new([ "trailer", ".mp4" ], binmode: true)
    begin
      attachment.blob.open do |file|
        transcode!(file.path, output.path)
      end
      output.rewind
      result = BunnyStorageService.call(output, kind: :audio_process, media: :video,
                                                filename: "#{File.basename(attachment.filename.to_s, '.*')}.mp4")
      unless result.stored?
        raise TransferFailed, result.error if result.retryable?

        give_up(result.error)
        return
      end

      product.reload
      return unless product.trailer_upload.attachment&.id == attachment_id

      product.update_columns(trailer_cdn_path: result.path, trailer_upload_error: nil)
      attachment.purge
    ensure
      output.close!
    end
  end

  def give_up(message)
    product, attachment_id = arguments
    return unless product.trailer_upload.attachment&.id == attachment_id

    product.update_column(:trailer_upload_error, message)
    product.trailer_upload.attachment&.purge
  end

  private

  def transcode!(input, output)
    ok = Timeout.timeout(1.hour) do
      system("ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", input,
             "-map", "0:v:0", "-map", "0:a:0?", "-vf", "scale='min(1280,iw)':-2",
             "-c:v", "libx264", "-preset", "veryfast", "-crf", "26",
             "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", output,
             out: File::NULL, err: File::NULL)
    end
    raise InvalidMedia, "Nie udało się przygotować filmu MP4. Sprawdź plik wideo." unless ok && File.size?(output)
  rescue Timeout::Error
    raise TransferFailed, "Przygotowanie filmu trwało zbyt długo."
  end
end
