class AudioChapterUploadJob < ApplicationJob
  queue_as :default

  class TransferFailed < StandardError; end
  retry_on TransferFailed, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.give_up(error.message)
  end

  def perform(chapter, attachment_id)
    attachment = chapter.audio_upload.attachment
    return unless attachment&.id == attachment_id

    result = nil
    duration = nil
    attachment.blob.open do |file|
      duration = MediaDurationService.call(file.path)
      result = BunnyStorageService.call(file, kind: :audio_process, filename: attachment.filename.to_s) if duration
    end
    unless duration
      give_up("Nie udało się odczytać długości nagrania. Sprawdź plik audio.")
      return
    end
    unless result.stored?
      raise TransferFailed, result.error if result.retryable?

      give_up(result.error)
      return
    end

    chapter.reload
    return unless chapter.audio_upload.attachment&.id == attachment_id

    chapter.update_columns(cdn_path: result.path, duration_seconds: duration, upload_error: nil)
    attachment.purge
  end

  def give_up(message)
    chapter, attachment_id = arguments
    return unless chapter.audio_upload.attachment&.id == attachment_id

    chapter.update_column(:upload_error, message)
    chapter.audio_upload.attachment&.purge
  end
end
