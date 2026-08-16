class PackagesController < ApplicationController
  def index
    @packages = Package.published.ordered
  end
end
