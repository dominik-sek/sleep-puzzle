# frozen_string_literal: true

module Admin
  # The audio shop: guided audio processes and bedtime stories.
  class ProductsController < BaseController
    include PurchasableManagement

    manages Product,
            label: "produkt",
            plain_attributes: %i[paddle_price_id kind icon position published]
  end
end
