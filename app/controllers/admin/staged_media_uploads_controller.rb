module Admin
  class StagedMediaUploadsController < BaseController
    before_action :load_upload, only: %i[chunk complete]

    def create
      type = params[:target_type].to_s
      target = case type
      when "Product" then Product.audio_process.find(params[:target_id])
      when "AudioChapter" then AudioChapter.joins(:product).merge(Product.audio_process).find(params[:target_id])
      else head :unprocessable_entity and return
      end

      upload = StagedMediaUpload.new(user: current_user, target_type: type, target_id: target.id,
                                     filename: params[:filename].to_s, byte_size: params[:byte_size],
                                     chunk_count: params[:chunk_count])
      if upload.save
        render json: { id: upload.id, chunk_bytes: StagedMediaUpload::CHUNK_BYTES }
      else
        render json: { error: upload.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end

    def chunk
      index = Integer(params[:index], exception: false)
      return head :unprocessable_entity unless index && index >= 0 && index < @upload.chunk_count

      @upload.with_lock do
        return head :conflict if @upload.completed_at?
        return head :unprocessable_content unless @upload.write_chunk(index, request.body)
      end
      head :no_content
    end

    def complete
      @upload.with_lock do
        return head :conflict if @upload.completed_at?
        return render json: { error: "Brakuje części pliku." }, status: :unprocessable_entity unless @upload.complete?

        target = @upload.target
        return head :not_found unless target

        blob = @upload.assemble_blob
        return head :unprocessable_content unless blob

        if @upload.video?
          target.trailer_upload.attach(blob)
          target.update_column(:trailer_upload_error, nil)
          ProductTrailerUploadJob.perform_later(target, target.trailer_upload.attachment.id)
          redirect = edit_admin_product_path(target)
        else
          target.audio_upload.attach(blob)
          target.update_column(:upload_error, nil)
          AudioChapterUploadJob.perform_later(target, target.audio_upload.attachment.id)
          redirect = edit_admin_product_path(target.product)
        end
        @upload.update!(completed_at: Time.current)
        render json: { redirect: redirect }
      end
    ensure
      @upload&.cleanup! if @upload&.completed_at?
    end

    private

    def load_upload
      @upload = current_user.staged_media_uploads.find(params[:id])
    end
  end
end
