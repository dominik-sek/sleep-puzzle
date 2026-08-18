class HomeController < ApplicationController
  # The home page is a shop window, not the catalogue: it shows the first few and
  # links to the full lists.
  PACKAGES_SHOWN = 3
  # four so the tile grid fills two even rows rather than leaving a gap
  PRODUCTS_SHOWN = 4

  def index
    @packages = Package.published.ordered.limit(PACKAGES_SHOWN)
    @products = Product.published.ordered.limit(PRODUCTS_SHOWN)
  end
end
