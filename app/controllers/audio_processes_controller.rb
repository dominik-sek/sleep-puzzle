class AudioProcessesController < ApplicationController
  def show
    @products = Product.published.audio_process.includes(:audio_chapters).ordered
  end
end
