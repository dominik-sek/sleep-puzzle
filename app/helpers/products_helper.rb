module ProductsHelper
  # Paddle owns the money (see Purchasable), so the amount is read back from the
  # price catalogue rather than stored here. Returns nil when Paddle is
  # unreachable or no longer knows the id — callers show the product as
  # unavailable rather than guessing at a number.
  def product_price_label(product)
    PaddlePriceCatalogService.find(product.paddle_price_id)&.formatted_amount
  end
end
