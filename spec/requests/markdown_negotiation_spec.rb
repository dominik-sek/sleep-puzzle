require "rails_helper"

RSpec.describe "Markdown content negotiation", type: :request do
  it "serves the home page as Markdown with cache variation" do
    get root_path, headers: { "Accept" => "text/markdown" }

    expect(response).to have_http_status(:ok)
    expect(response.content_type).to eq("text/markdown; charset=utf-8")
    expect(response.headers["Vary"].split(/,\s*/)).to include("Accept")
    expect(response.body).to include("# ", "Jak mogę Ci pomóc", "[", packages_path)
    expect(response.body).not_to match(/<\/?(?:html|div|script|style|svg|nav)\b/)
  end

  it "converts published article content including headings, lists and links" do
    article = create_article(body: '<h2>Plan snu</h2><p>Spokojny wieczór.</p><ul><li>Stała pora</li></ul><p><a href="/packages">Konsultacje</a></p>')

    get article_path(slug: article.slug), headers: { "Accept" => "text/markdown" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("# Sen niemowlaka", "## Plan snu", "Spokojny wieczór.", "- Stała pora", "[Konsultacje](/packages)")
    expect(response.body).not_to include("<", "data-controller", "csrf-token")
  end

  it "uses the requested locale" do
    get root_path(locale: :en), headers: { "Accept" => "text/markdown, text/html;q=0.5" }

    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to include("How can I help you?", "/en/packages")
  end

  [ nil, "*/*", "text/html", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "text/html;q=1, text/markdown;q=0.5", "text/markdown;q=0, text/html" ].each do |accept|
    it "keeps HTML for Accept #{accept.inspect}" do
      get root_path, headers: accept ? { "Accept" => accept } : {}

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("<!DOCTYPE html>")
      expect(response.headers["Vary"].split(/,\s*/)).to include("Accept")
    end
  end

  it "honors an explicit Markdown preference even with a wildcard fallback" do
    get root_path, headers: { "Accept" => "text/markdown, */*;q=0.1" }

    expect(response.media_type).to eq("text/markdown")
  end

  it "returns Markdown headers and no body for HEAD" do
    head root_path, headers: { "Accept" => "text/markdown" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to be_empty
  end

  it "preserves redirects and authentication" do
    get dashboard_index_path, headers: { "Accept" => "text/markdown" }

    expect(response).to redirect_to(new_user_session_path)
  end

  it "does not expose unpublished articles" do
    article = create_article(published: false)

    get article_path(slug: article.slug), headers: { "Accept" => "text/markdown" }

    expect(response).to have_http_status(:not_found)
  end

  it "preserves explicitly requested non-HTML representations" do
    get feed_articles_path(format: :rss), headers: { "Accept" => "text/markdown" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/rss+xml")
  end
end
