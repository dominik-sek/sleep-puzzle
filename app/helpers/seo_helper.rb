# Helpers for search-engine and AI-crawler discovery: meta description, canonical,
# Open Graph and Schema.org JSON-LD. Everything is first-party HTML/JSON - there is
# no third-party asset here, so the privacy commitment (a passive reader makes no
# third-party request) is untouched.
#
# The *copy* these emit (brand name, default description, social link) is editable
# in the admin panel under SEO -> Wyszukiwarka i AI, so it can change without a
# deploy. The schema structure stays in code: a typo there silently breaks rich
# results, and that is not something the owner should be able to do.
module SeoHelper
  # The page's description: the per-page override when a view sets
  # `content_for :meta_description`, else the owner-editable site default.
  def meta_description
    content_for(:meta_description).presence || content_block("seo.site.meta_description")
  end

  # The owner-editable brand name, used in Open Graph and structured data rather
  # than hardcoded so a rename in the panel flows through to search and AI.
  def brand_name
    content_block("seo.site.brand_name").presence || "Sleep Puzzle"
  end

  # The one canonical address for this page, including the query string so a
  # paginated index (`/blog?page=2`) self-canonicals rather than claiming page 1
  # as its duplicate. The locale is already in the path (bare for Polish, /en for
  # English), and this matches the layout's hreflang alternates, which also
  # preserve the query string. Doubles as the Open Graph URL.
  def canonical_url
    request.base_url + request.original_fullpath
  end

  # The image for social/LLM previews: the article cover when there is one, else
  # the site icon. Absolute, because crawlers need a full URL.
  def og_image_url
    absolute_url(content_for(:og_image).presence || "/icon.png")
  end

  # Renders a Hash as a <script type="application/ld+json"> block, escaped so that
  # owner-authored copy cannot break out of the script element.
  def json_ld(data)
    tag.script(type: "application/ld+json") do
      json_escape(data.to_json).html_safe
    end
  end

  # Who Sleep Puzzle is and the site itself. Emitted once in the public layout.
  def site_json_ld
    {
      "@context" => "https://schema.org",
      "@graph" => [ organization_json_ld, website_json_ld ]
    }
  end

  # A blog article as a BlogPosting, for search snippets and AI answer engines.
  def article_json_ld(article)
    {
      "@context" => "https://schema.org",
      "@type" => "BlogPosting",
      "headline" => article.title,
      "description" => (article.meta_description.presence || article.excerpt).to_s,
      "datePublished" => article.display_date.iso8601,
      "dateModified" => article.updated_at.iso8601,
      "mainEntityOfPage" => { "@type" => "WebPage", "@id" => canonical_url },
      "image" => article_image_url(article),
      "author" => { "@type" => "Person", "name" => owner_name },
      "publisher" => {
        "@type" => "Organization",
        "name" => brand_name,
        "logo" => { "@type" => "ImageObject", "url" => absolute_url("/icon.png") }
      },
      "inLanguage" => I18n.locale.to_s
    }.compact
  end

  private

  def organization_json_ld
    {
      "@type" => "Organization",
      "@id" => "#{request.base_url}/#organization",
      "name" => brand_name,
      "url" => request.base_url,
      "logo" => absolute_url("/icon.png"),
      "founder" => { "@type" => "Person", "name" => owner_name },
      "sameAs" => [ instagram_url ]
    }
  end

  def website_json_ld
    {
      "@type" => "WebSite",
      "@id" => "#{request.base_url}/#website",
      "url" => request.base_url,
      "name" => brand_name,
      "inLanguage" => [ "pl", "en" ]
    }
  end

  # The owner's display name follows the CMS, so a rename in the panel flows
  # through to the structured data rather than leaving a stale hardcoded name.
  def owner_name
    content_block("about.intro.name").presence || "Karola"
  end

  # The owner-editable Instagram address for structured data's `sameAs`.
  def instagram_url
    content_block("seo.site.instagram").presence || instagram_contact_url
  end

  def article_image_url(article)
    return unless article.cover_image.attached?

    absolute_url(url_for(article.cover_image.variant(resize_to_limit: [ 1200, 630 ])))
  end

  def absolute_url(path_or_url)
    return if path_or_url.blank?
    return path_or_url if path_or_url.start_with?("http")

    "#{request.base_url}#{path_or_url}"
  end
end
