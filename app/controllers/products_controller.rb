class ProductsController < ApplicationController
  # How many "Inne materiały" tiles sit under a product, matching the design's row.
  ALSO_LIMIT = 3

  # Long enough to start playing and seek within a 30-second clip, short enough
  # that a copied URL is not a durable way to hand the sample around.
  PREVIEW_TTL = 15.minutes

  before_action :authenticate_user!, only: :stream

  def index
    @products = Product.published.ordered
  end

  # Read through the published scope, so an unpublished product 404s rather than
  # rendering a page that cannot be bought.
  def show
    @product = Product.published.find(params[:id])
    @also = Product.published.ordered.where.not(id: @product.id).limit(ALSO_LIMIT)
  end

  # Hands a buyer their own copy. /dashboard renders a player pointed here, and
  # this turns "you own it" into a URL Bunny will serve for the next few hours.
  #
  # A redirect rather than the signed URL rendered straight into the dashboard:
  # the token key never reaches the HTML, the URL is minted when play is pressed
  # rather than baked into a page that may sit open for a day, and moving a file
  # on the CDN cannot strand a link someone already has.
  def stream
    product = Product.published.find(params[:id])

    # 403 rather than 404: the shop lists this product, so its existence is not
    # the secret — the file behind it is
    head :forbidden and return unless current_user.purchased?(product)

    url = BunnySignedUrlService.call(product.cdn_path)

    # Nothing uploaded, or a deploy that lost the CDN credentials. The dashboard
    # only draws a player when Product#streamable?, so reaching this is either a
    # stale page or a hand-typed URL.
    head :not_found and return if url.nil?

    redirect_to url, allow_other_host: true
  end

  # The shop's 30-second sample. No ownership check and no sign-in: this exists to
  # be heard by someone who has bought nothing. It signs `preview_cdn_path`, which
  # is a separate object in the storage zone — the full recording's path is never
  # reachable from here, so there is nothing to leak by leaving it open.
  #
  # A short TTL because a preview is pressed and heard in one sitting, unlike the
  # full stream, which is signed for six hours so a parent can pause and come back.
  def preview
    product = Product.published.find(params[:id])

    head :not_found and return unless product.previewable?

    url = BunnySignedUrlService.call(product.preview_cdn_path, expires_in: PREVIEW_TTL)
    head :not_found and return if url.nil?

    redirect_to url, allow_other_host: true
  end
end
