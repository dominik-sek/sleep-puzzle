class ProductsController < ApplicationController
  def index
    @products = Product.published.ordered
  end

  # Read through the published scope, so an unpublished product 404s rather than
  # rendering a page that cannot be bought.
  def show
    @product = Product.published.find(params[:id])
  end
end
