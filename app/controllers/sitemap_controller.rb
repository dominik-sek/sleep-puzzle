# Serves /sitemap.xml: the fixed public pages plus every published article, in
# both languages with hreflang alternates. This is the standard discovery feed
# search engines and AI crawlers read, so it lists exactly what a visitor can reach.
class SitemapController < ApplicationController
  layout false

  def index
    @entries = static_entries + article_entries
  end

  private

  def static_entries
    [
      root_path(locale: nil),
      about_path(locale: nil),
      packages_path(locale: nil),
      products_path(locale: nil),
      audio_processes_path(locale: nil),
      stories_path(locale: nil),
      articles_path(locale: nil),
      terms_path(locale: nil),
      refunds_path(locale: nil),
      privacy_path(locale: nil),
      contact_path(locale: nil)
    ].map { |path| { pl: absolute(path), en: absolute(english(path)), lastmod: nil } }
  end

  def article_entries
    Article.published.newest.map do |article|
      {
        pl: absolute(article_path(slug: article.slug, locale: nil)),
        en: absolute(article_path(slug: article.slug, locale: "en")),
        lastmod: article.updated_at
      }
    end
  end

  # The same page under /en. The root is the one path without its own segment.
  def english(path)
    path == "/" ? "/en" : "/en#{path}"
  end

  def absolute(path)
    "#{request.base_url}#{path}"
  end
end
