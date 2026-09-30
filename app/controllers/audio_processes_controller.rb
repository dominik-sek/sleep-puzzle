class AudioProcessesController < ApplicationController
  def show
    @product = Product.published.audio_process.ordered.first
  end
end
