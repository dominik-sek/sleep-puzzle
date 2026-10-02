class AudioProcessesController < ApplicationController
  def show
    @product = Product.published.audio_process.includes(:audio_chapters).ordered.first
  end
end
