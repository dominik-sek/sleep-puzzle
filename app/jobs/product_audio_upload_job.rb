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

  # Updates the row and the form wherever the panel is open, and pops a toast —
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
end
