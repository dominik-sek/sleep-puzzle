require "rails_helper"

RSpec.describe Article, type: :model do
  describe "slug" do
    it "generates from the Polish title on create" do
      article = create_article(title: "Sen niemowlaka: od czego zacząć")

      expect(article.slug).to eq("sen-niemowlaka-od-czego-zaczac")
    end

    it "appends a suffix rather than colliding" do
      create_article(title: "Sen niemowlaka")
      second = create_article(title: "Sen niemowlaka")

      expect(second.slug).to eq("sen-niemowlaka-2")
    end

    it "records the slug in its history" do
      article = create_article(title: "Sen niemowlaka")

      expect(article.slug_histories.map(&:slug)).to include("sen-niemowlaka")
    end

    it "refuses a slug another article already used" do
      create_article(title: "Pierwszy", slug: "wspolny")
      other = build_article(title: "Drugi", slug: "wspolny")

      expect(other).not_to be_valid
      expect(other.errors[:slug]).to be_present
    end
  end

  describe "publication" do
    it "stamps published_at on the first publish" do
      article = create_article(published: true)

      expect(article.published_at).to be_present
    end

    it "leaves published_at blank for a draft" do
      article = create_article(published: false)

      expect(article.published_at).to be_nil
    end

    it "scopes published to visible articles" do
      published = create_article(title: "Widoczny")
      create_article(title: "Szkic", published: false)

      expect(Article.published).to contain_exactly(published)
    end
  end

  describe "translation fallback" do
    it "falls back to Polish when English is empty" do
      article = create_article(title: "Tylko po polsku", body: "<div>Polska treść.</div>")

      expect(I18n.with_locale(:en) { article.title }).to eq("Tylko po polsku")
      expect(I18n.with_locale(:en) { article.body.to_plain_text }).to include("Polska treść.")
    end
  end

  describe "#reading_minutes" do
    it "returns at least one minute" do
      expect(create_article(body: "Krótki tekst").reading_minutes).to eq(1)
    end
  end
end
