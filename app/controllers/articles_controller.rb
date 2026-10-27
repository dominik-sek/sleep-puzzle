class ArticlesController < ApplicationController
  def index
    @pagy, @articles = pagy(Article.published.newest.with_attached_cover_image.with_rich_text_body_pl.with_rich_text_body_en)
  end

  # The RSS feed of published articles, for feed readers and aggregators.
  def feed
    @articles = Article.published.newest.limit(20)
    respond_to do |format|
      format.rss { render layout: false }
    end
  end

  # Read through the published scope, so an unpublished article 404s rather than
  # rendering a page that is not meant to be live yet. An old slug (after a
  # rename) redirects to the current one, mirroring how product slugs behave, so
  # a link that once worked keeps resolving instead of going dead.
  def show
    @article = Article.published.find_by(slug: params[:slug]) ||
      Article.published.joins(:slug_histories)
              .find_by!(article_slug_histories: { slug: params[:slug] })

    return if @article.slug == params[:slug]

    target = request.query_parameters.merge(request.path_parameters)
                     .merge(slug: @article.slug, only_path: true)
    redirect_to url_for(target), status: :moved_permanently
  end
end
