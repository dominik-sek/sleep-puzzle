class PackagesController < ApplicationController
  def index
    @packages = Package.published.ordered
  end

  def show
    @package = Package.published.find(params[:id])
  end
end
