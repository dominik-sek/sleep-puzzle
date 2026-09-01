module PackagesHelper
  # The same join as ProductsHelper#product_price_label: Paddle owns the money
  # (see Purchasable), so the amount is read back from the price catalogue rather
  # than stored here. Returns nil when Paddle is unreachable or no longer knows
  # the id - the card then shows the package as unavailable and drops its booking
  # button, because a package we cannot price is a package we cannot sell.
  def package_price_label(package)
    PaddlePriceCatalogService.find(package.paddle_price_id)&.formatted_amount
  end
end
