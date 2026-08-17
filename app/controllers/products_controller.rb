class ProductsController < ApplicationController
  # How many "Inne materiały" tiles sit under a product, matching the design's row.
  ALSO_LIMIT = 3

  def index
    @products = Product.published.ordered
  end

  # Read through the published scope, so an unpublished product 404s rather than
  # rendering a page that cannot be bought.
  def show
    @product = Product.published.find(params[:id])
    @also = Product.published.ordered.where.not(id: @product.id).limit(ALSO_LIMIT)
  end
end
