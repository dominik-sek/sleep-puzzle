module ProductDelivery
  extend ActiveSupport::Concern

  # How many "Inne materiały" tiles sit under a product, matching the design's row.
  ALSO_LIMIT = 3

  # Long enough to start playing and seek within a 30-second clip, short enough
  # that a copied URL is not a durable way to hand the sample around.
  PREVIEW_TTL = 15.minutes

  included do
    before_action :authenticate_user!, only: %i[stream stream_chapter]
    before_action :resolve_product, only: %i[show stream stream_chapter trailer preview]
  end

  # Read through the published scope, so an unpublished product 404s rather than
  # rendering a page that cannot be bought.
  def show
    @also = product_scope.published.includes(:audio_chapters).ordered.where.not(id: @product.id).limit(ALSO_LIMIT)
    render "products/show"
  end

  # Hands a buyer their own copy. /dashboard renders a player pointed here, and
  # this turns "you own it" into a URL Bunny will serve for the next few hours.
  #
  # A redirect rather than the signed URL rendered straight into the dashboard:
  # the token key never reaches the HTML, the URL is minted when play is pressed
  # rather than baked into a page that may sit open for a day, and moving a file
  # on the CDN cannot strand a link someone already has.
  def stream
    product = @product
    head :not_found and return unless product.bedtime_story?

    # 403 rather than 404: the shop lists this product, so its existence is not
    # the secret - the file behind it is
    issue_stream(product, product.cdn_path)
  end

  def stream_chapter
    product = @product
    chapter = product.audio_chapters.ready.find(params[:chapter_id])
    issue_stream(product, chapter.cdn_path)
  end

  def trailer
    product = @product
    head :not_found and return unless product.trailerable?

    url = BunnySignedUrlService.call(product.trailer_cdn_path)
    head :not_found and return unless url

    redirect_to url, allow_other_host: true
  end

  # The shop's 30-second sample. No ownership check and no sign-in: this exists to
  # be heard by someone who has bought nothing. It signs `preview_cdn_path`, which
  # is a separate object in the storage zone - the full recording's path is never
  # reachable from here, so there is nothing to leak by leaving it open.
  #
  # A short TTL because a preview is pressed and heard in one sitting, unlike the
  # full stream, which is signed for six hours so a parent can pause and come back.
  def preview
    product = @product

    head :not_found and return unless product.previewable?

    url = BunnySignedUrlService.call(product.preview_cdn_path, expires_in: PREVIEW_TTL)
    head :not_found and return if url.nil?

    redirect_to url, allow_other_host: true
  end

  private

  def resolve_product
    # Buyers retain chapter access after a program is unpublished. Every other
    # action keeps its existing publication requirement, including redirects.
    scope = action_name == "stream_chapter" ? product_scope : product_scope.published
    scope = scope.includes(:audio_chapters) if action_name == "show"
    @product = scope.find_by(slug: params[:slug]) ||
      scope.joins(:slug_histories).find_by!(product_slug_histories: { slug: params[:slug] })
    return if @product.slug == params[:slug]

    target = request.query_parameters.merge(request.path_parameters).merge(slug: @product.slug, only_path: true)
    redirect_to url_for(target), status: :moved_permanently
  end

  def issue_stream(product, path)
    items = current_user.accessible_order_items.where(product_id: product.id)
    items = items.where(id: params[:order_item_id]) if params[:order_item_id].present?
    item = items.order(id: :desc).first
    return head :forbidden unless item

    item.order.with_lock do
      item.reload
      return head :forbidden if item.refunded_at? || !item.order.paid?

      url = BunnySignedUrlService.call(path)
      return head :not_found unless url

      item.update!(first_stream_issued_at: Time.current) unless item.first_stream_issued_at?
      redirect_to url, allow_other_host: true
    end
  end
end
