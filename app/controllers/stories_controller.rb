class StoriesController < ApplicationController
  def index
    @products = Product.published.bedtime_story.ordered
  end
end
