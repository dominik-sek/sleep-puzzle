# Sends a recording staged by the admin form (Product#audio_upload) on to Bunny,
# so the request that received it does not wait for the second copy.
class ProductAudioUploadJob < ApplicationJob
  queue_as :default

  # Raised rather than recorded so ActiveJob's retries handle it.
  class TransferFailed < StandardError; end

  discard_on ActiveJob::DeserializationError

  retry_on TransferFailed, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.give_up(error.message)
  end

  def perform(product)
    # this run's attachment, not the association: an upload that replaced it
    # while this was in flight must not be the one purged below
    attachment = product.audio_upload.attachment
    return if attachment.blank?

    result = transfer(attachment, product.kind)
    raise TransferFailed, result.error if !result.stored? && result.retryable?

    if result.stored?
      store_path(product, result.path)
      # after the real file is safely stored, never before: a preview is worth
      # nothing if the thing it previews did not land, and a failure here must
      # not cost the upload its retry budget
      store_preview(product, attachment)
      attachment.purge
      notify(product, type: "success", title: "Wgrano plik audio do „#{product.name}”.")
    else
      give_up(result.error)
    end
  end

  # Public and argument-read because retry_on's block calls it on a job instance
  # that has never been through #perform.
  def give_up(message)
    product = arguments.first

    Rails.logger.error("Audio upload for product #{product.id} failed: #{message}")
    product.update_column(:audio_upload_error, message)
    product.audio_upload.attachment&.purge
    notify(product, type: "error", title: "Nie udało się wgrać pliku do „#{product.name}”.",
                    description: message)
  end

  private

  # Updates the row and the form wherever the panel is open, and pops a toast -
  # the upload finishes long after the request that started it, so there is
  # otherwise nothing to tell the owner but a refresh.
  def notify(product, **toast)
    Turbo::StreamsChannel.broadcast_render_to(
      Product::ADMIN_STREAM,
      template: "admin/products/audio_upload_finished",
      locals: { product: product.reload, toast: toast }
    )
  end

  # The filename goes along separately because blob.open's tempfile is named
  # after the blob key.
  def transfer(attachment, kind)
    result = nil

    attachment.blob.open do |file|
      result = BunnyStorageService.call(file, kind: kind, filename: attachment.filename.to_s)
    end

    result
  end

  # update_columns: a product may sit published while its file is in flight, and
  # validating here would refuse the write that resolves that.
  def store_path(product, path)
    product.update_columns(cdn_path: path, audio_upload_error: nil)
    Rails.logger.info("Audio for product #{product.id} landed at #{path}")
  end

  # The shop's 30-second sample. Deliberately best-effort: everything in here is
  # rescued, because a product that cannot be previewed is still a product that
  # can be sold, and the owner should not see an upload fail over a sample.
  def store_preview(product, attachment)
    preview = nil

    attachment.blob.open do |file|
      preview = AudioPreviewService.call(file.path)
    end
    return if preview.nil?

    result = BunnyStorageService.call(preview, kind: product.kind,
                                               filename: preview_filename(attachment))
    if result.stored?
      product.update_columns(preview_cdn_path: result.path)
      Rails.logger.info("Preview for product #{product.id} landed at #{result.path}")
    else
      Rails.logger.warn("Preview upload for product #{product.id} failed: #{result.error}")
    end
  rescue StandardError => e
    Rails.logger.warn("Preview for product #{product.id} could not be made: #{e.class}: #{e.message}")
  ensure
    preview&.close!
  end

  # Distinct from the full file's name so the two never collide in the zone, and
  # .mp3 because the cut is always transcoded to it whatever went in.
  def preview_filename(attachment)
    "#{File.basename(attachment.filename.to_s, '.*')}-preview.mp3"
  end
end
