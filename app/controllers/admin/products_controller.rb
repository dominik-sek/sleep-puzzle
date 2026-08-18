# frozen_string_literal: true

module Admin
  # The audio shop: guided audio processes and bedtime stories.
  class ProductsController < BaseController
    include PurchasableManagement

    manages Product,
            label: "produkt",
            plain_attributes: %i[paddle_price_id kind icon length_minutes cdn_path position published]

    private

    # The one thing this catalogue does that packages do not: the recording itself
    # is uploaded here rather than through Bunny's dashboard, so a product and its
    # audio are saved in one action.
    #
    # The file goes to Bunny before the record is saved, not after, so that a
    # storage zone which is down or misconfigured re-renders the form with
    # everything the owner typed still in it, instead of quietly saving a product
    # whose player never appears. The cost of that order is an orphaned file in the
    # zone when the upload lands but the save then fails validation — cheap next to
    # a saved product pointing at a file that was never written.
    def save_record
      upload = params.dig(:record, :audio)
      return super if upload.blank?

      # assigned before the upload because the folder the recording lands in
      # follows the product's kind, and on an edit that may be on the record
      # already rather than in the submitted form
      @record.assign_attributes(plain_params)

      result = BunnyStorageService.call(upload, kind: @record.kind)
      return upload_failed(result) unless result.stored?

      # where the file now actually is, which beats whatever path the form carried
      params[:record][:cdn_path] = result.path

      super
    end

    # Assigns before validating so the re-rendered form still shows what was
    # submitted, and adds the upload's own error last because `validate` clears the
    # errors it is about to repopulate.
    def upload_failed(result)
      @record.assign_attributes(plain_params)
      assign_translations
      @record.validate
      @record.errors.add(:base, result.error)

      false
    end
  end
end
