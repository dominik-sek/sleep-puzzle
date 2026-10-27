class HomeController < ApplicationController
  # The home page is a shop window, not the catalogue: it shows the first few and
  # links to the full lists.
  PACKAGES_SHOWN = 3
  # four so the tile grid fills two even rows rather than leaving a gap
  PRODUCTS_SHOWN = 4
  # three so the blog strip sits in one row of cards on a desktop
  ARTICLES_SHOWN = 3

  def index
    @packages = Package.published.ordered.limit(PACKAGES_SHOWN)
    @products = Product.published.includes(:audio_chapters).ordered.limit(PRODUCTS_SHOWN)
    @articles = Article.published.newest.with_attached_cover_image.with_rich_text_body_pl.with_rich_text_body_en.limit(ARTICLES_SHOWN)
  end
end
