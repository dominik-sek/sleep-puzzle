class HomeController < ApplicationController
  # The home page is a shop window, not the catalogue: it shows the first few and
  # links to the full lists.
  PACKAGES_SHOWN = 3
  PRODUCTS_SHOWN = 3

  def index
    @packages = Package.published.ordered.limit(PACKAGES_SHOWN)
    @products = Product.published.ordered.limit(PRODUCTS_SHOWN)
  end
end
