class StoriesController < ApplicationController
  include ProductDelivery

  def index
    @products = product_scope.published.ordered
  end

  private

  def product_scope
    Product.bedtime_story
  end
end
