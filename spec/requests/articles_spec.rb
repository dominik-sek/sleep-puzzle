require "rails_helper"

RSpec.describe "Blog", type: :request do
  it "lists published articles and omits drafts" do
    create_article(title: "Widoczny artykuł", excerpt: "Zajawka widoczna")
    create_article(title: "Szkic", published: false)

    get articles_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Widoczny artykuł", "Zajawka widoczna")
    expect(response.body).not_to include("Szkic")
  end

  it "renders an article with its title, excerpt and BlogPosting structured data" do
    article = create_article(title: "Sen niemowlaka", excerpt: "Pierwsze kroki")

    get article_path(slug: article.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sen niemowlaka", "Pierwsze kroki", %("BlogPosting"))
  end

  it "404s an unpublished article" do
    article = create_article(title: "Szkic", published: false)

    get article_path(slug: article.slug)

    expect(response).to have_http_status(:not_found)
  end

  it "redirects an old slug to the current one" do
    article = create_article(title: "Pierwszy")
    old_path = article_path(slug: article.slug)
    article.assign_translation(:title, :pl, "Drugi")
    article.slug = article.suggested_slug
    article.save!

    get old_path

    expect(response).to have_http_status(:moved_permanently)
    expect(response).to redirect_to(article_path(slug: article.slug))
  end

  it "renders the RSS feed" do
    create_article(title: "Sen niemowlaka", excerpt: "Zajawka")

    get feed_articles_path(format: :rss)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/rss+xml")
    expect(response.body).to include("Sen niemowlaka")
    # the self link must point at the feed, not at /blog.rss (the index helper)
    expect(response.body).to include(%(<atom:link href="#{feed_articles_url(format: :rss)}"))
  end
end
