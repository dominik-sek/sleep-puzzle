require "rails_helper"

RSpec.describe "Admin articles", type: :request do
  let(:admin) { User.create!(email: "blog-admin@example.com", password: "password123", admin: true) }

  before { sign_in admin }

  it "lists articles" do
    create_article(title: "Sen niemowlaka")

    get admin_articles_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sen niemowlaka")
  end

  it "renders the edit form with the live article preview" do
    article = create_article(title: "Istniejący", body: "<div>Treść</div>")

    get edit_admin_article_path(article)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Podgląd artykułu", "Istniejący")
  end

  it "creates an article from the form" do
    expect {
      post admin_articles_path, params: {
        record: {
          slug: "",
          published: "1",
          translations: { title: { pl: "Nowy artykuł" }, excerpt: { pl: "Zajawka" } },
          body: { pl: "<div>Treść</div>", en: "" }
        }
      }
    }.to change(Article, :count).by(1)

    article = Article.last
    expect(article.title).to eq("Nowy artykuł")
    expect(article).to be_published
    expect(article.slug).to eq("nowy-artykul")
  end

  it "updates an article" do
    article = create_article(title: "Stary tytuł")

    patch admin_article_path(article), params: {
      record: { published: "0", translations: { title: { pl: "Nowy tytuł" } } }
    }

    expect(article.reload.title).to eq("Nowy tytuł")
    expect(article.reload).not_to be_published
  end

  it "destroys an article" do
    article = create_article(title: "Do usunięcia")

    expect { delete admin_article_path(article) }.to change(Article, :count).by(-1)
  end

  it "previews an article from the form without saving it" do
    expect {
      post preview_admin_articles_path, params: {
        record: {
          translations: { title: { pl: "Podglądany artykuł" }, excerpt: { pl: "Zajawka podglądu" } },
          body: { pl: "<div>Treść podglądu</div>", en: "" }
        },
        preview_locale: "pl"
      }
    }.not_to change(Article, :count)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Podglądany artykuł", "Treść podglądu")
  end

  it "redirects non-admins away" do
    admin.update!(admin: false)

    get admin_articles_path

    expect(response).to redirect_to(root_path)
  end
end
