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
  end
end
