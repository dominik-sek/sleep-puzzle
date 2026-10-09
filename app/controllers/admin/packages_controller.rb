# frozen_string_literal: true

module Admin
  # The consultation packages sold on the site. `duration` is the length of the
  # support in weeks, and it is not translated - a number reads the same in both
  # languages.
  class PackagesController < BaseController
    include PurchasableManagement

    manages Package,
            label: "pakiet",
            plain_attributes: %i[paddle_price_id duration position published]

    # Render the submitted copy with the public templates, without saving even
    # an existing package. Reuse the save path's translation/list normalization.
    def preview
      @record = managed_model.new(plain_params)
      assign_translations

      locale = params[:preview_locale].presence_in(Translatable::LOCALES.map(&:to_s)) || "pl"
      I18n.with_locale(locale) do
        render partial: "preview", locals: { package: @record }
      end
    end
  end
end
