class ProductsController < ApplicationController
  def index
    @products = Product.published.includes(:audio_chapters).ordered
    @packages = Package.published.ordered
  end
end
