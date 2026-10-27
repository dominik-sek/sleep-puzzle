require "rails_helper"

RSpec.describe "SEO and AI discovery", type: :request do
  it "emits site structured data in the public layout" do
    get root_path

    expect(response.body).to include(%("Organization"), %("WebSite"), %("Sleep Puzzle"))
  end

  it "preserves the query string in the canonical URL" do
    get root_path, params: { page: "2" }

    canonical = response.body[/rel="canonical" href="([^"]+)"/, 1]
    expect(canonical).to end_with("/?page=2")
  end

  it "uses the owner's brand name and description once edited in the panel" do
    ContentBlock.sync!
    ContentBlock.find_by!(key: "seo.site.brand_name").update!(value_pl: "Nowa Marka")
    ContentBlock.find_by!(key: "seo.site.meta_description").update!(value_pl: "Opis właściciela")

    get root_path

    expect(response.body).to include(%("name":"Nowa Marka"))
    expect(response.body).to include("Opis właściciela")
  end

  it "renders the sitemap with articles and hreflang alternates" do
    article = create_article(title: "Sen niemowlaka")

    get sitemap_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(article_path(slug: article.slug, locale: nil))
    expect(response.body).to include(article_path(slug: article.slug, locale: "en"))
    expect(response.body).to include(%(hreflang="pl"), %(hreflang="en"))
  end

  it "renders llms.txt with article links" do
    create_article(title: "Sen niemowlaka", excerpt: "Zajawka")

    get llms_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sen niemowlaka", "Zajawka")
  end

  it "renders llms-full.txt with article bodies" do
    create_article(title: "Sen niemowlaka", body: "<div>Pełna treść artykułu.</div>")

    get llms_full_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sen niemowlaka", "Pełna treść artykułu.")
  end
end
