# frozen_string_literal: true

module Admin
  # The audio shop: guided audio processes and bedtime stories.
  class ProductsController < BaseController
    include PurchasableManagement

    manages Product,
            label: "produkt",
            plain_attributes: %i[paddle_price_id kind icon length_minutes cdn_path position published]

    private

    # the row badge asks each product about its attachment
    def index_scope
      super.with_attached_audio_upload
    end

    # The recording is uploaded here rather than through Bunny's dashboard, but
    # only as far as our own disk: ProductAudioUploadJob carries it the rest of
    # the way. Everything that can refuse a file without a network call still
    # happens here, so a bad file comes back on the form.
    def save_record
      upload = params.dig(:record, :audio)
      return super if upload.blank?

      # the record keeps serving its current file until the job has somewhere new
      # to point it, so a path submitted alongside the upload is dropped
      params[:record].delete(:cdn_path)

      # assigned first: the folder follows the product's kind, which on an edit
      # may be on the record rather than in the form
      @record.assign_attributes(plain_params)

      staged = staged_upload(upload)
      return upload_failed("Nie udało się odczytać wgranego pliku. Spróbuj ponownie.") if staged.blank?

      rejection = BunnyStorageService.rejection_for(kind: @record.kind, **describe(staged))
      return upload_failed(rejection) if rejection

      # before the save, so a product published in the same submit still validates
      @record.audio_upload.attach(upload)
      @record.audio_upload_error = nil

      return purge_staged_upload unless super

      ProductAudioUploadJob.perform_later(@record)

      true
    end

    # The uploader posts a signed blob id — the file reached the server before the
    # form did, which is what the progress bar was measuring. A browser with no
    # JS posts the file itself; both are attachable and both are checked below.
    def staged_upload(upload)
      return upload unless upload.is_a?(String)

      ActiveStorage::Blob.find_signed(upload)
    end

    def describe(staged)
      if staged.is_a?(ActiveStorage::Blob)
        { filename: staged.filename.to_s, size: staged.byte_size }
      else
        { filename: staged.original_filename, size: staged.size }
      end
    end

    # no job was enqueued, so the file would sit there reading as "in progress"
    def purge_staged_upload
      @record.audio_upload.purge

      false
    end

    # Assigns before validating so the re-rendered form still shows what was
    # submitted, and adds the upload's own error last because `validate` clears the
    # errors it is about to repopulate.
    def upload_failed(message)
      @record.assign_attributes(plain_params)
      assign_translations
      @record.validate
      @record.errors.add(:base, message)

      false
    end

    def upload_pending_notice
      return unless @record.audio_upload_pending?

      " Plik audio wgrywa się w tle — odśwież za chwilę."
    end

    def create_notice
      "#{super}#{upload_pending_notice}"
    end

    def update_notice
      "#{super}#{upload_pending_notice}"
    end
  end
end
