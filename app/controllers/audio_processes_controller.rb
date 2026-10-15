class AudioProcessesController < ApplicationController
  include ProductDelivery

  def index
    @products = product_scope.published.includes(:audio_chapters).ordered
  end

  private

  def product_scope
    Product.audio_process
  end
end
