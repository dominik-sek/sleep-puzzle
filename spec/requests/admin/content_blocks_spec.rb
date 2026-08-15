require 'rails_helper'

RSpec.describe "Admin::ContentBlocks", type: :request do
  let(:admin) { User.create!(email: "owner@example.com", password: "password123", admin: true) }
  let(:customer) { User.create!(email: "customer@example.com", password: "password123") }

  before { ContentBlock.sync! }

  it "is closed to non-admins" do
    sign_in customer

    get admin_content_blocks_path

    expect(response).to redirect_to(root_path)
  end

  describe "GET /admin/content_blocks" do
    before { sign_in admin }

    it "renders every page, section and field on one screen" do
      get admin_content_blocks_path

      expect(response).to have_http_status(:ok)
      ContentBlock::Registry.pages.each do |page|
        expect(response.body).to include(page.label)
        page.sections.each { |section| expect(response.body).to include(section.label) }
      end
    end

    it "gives each section its own form and anchor" do
      get admin_content_blocks_path

      sections = ContentBlock::Registry.sections
      expect(response.body.scan('name="section"').size).to eq(sections.size)
      sections.each do |section|
        expect(response.body).to include(%(id="section-#{section.page.key}-#{section.key}"))
        expect(response.body).to include(%(href="#section-#{section.page.key}-#{section.key}"))
      end
    end

    it "renders a Trix editor per language for rich fields and a text input for plain ones" do
      get admin_content_blocks_path

      rich = ContentBlock::Registry.fields.count(&:rich?)
      expect(response.body.scan("<trix-editor").size).to eq(rich * ContentBlock::LOCALES.size)
      expect(response.body).to include(%(name="fields[title][pl]"))
    end

    it "emits no duplicate DOM ids" do
      get admin_content_blocks_path

      ids = response.body.scan(/id="([^"]+)"/).flatten
      expect(ids).to eq(ids.uniq)
    end
  end

  describe "PATCH /admin/content_blocks" do
    before { sign_in admin }

    it "saves the submitted section in both languages" do
      patch admin_content_blocks_path, params: {
        section: "home.hero",
        fields: {
          title: { pl: "Tytuł", en: "Title" },
          subtitle: { pl: "<div>Podtytuł</div>", en: "<div>Subtitle</div>" }
        }
      }

      expect(response).to redirect_to(admin_content_blocks_path(anchor: "section-home-hero"))
      expect(ContentBlock.find_by(key: "home.hero.title").value_pl).to eq("Tytuł")
      expect(ContentBlock.find_by(key: "home.hero.title").value_en).to eq("Title")
      expect(ContentBlock.find_by(key: "home.hero.subtitle").body_pl.body.to_html).to include("Podtytuł")
    end

    it "leaves other sections untouched" do
      ContentBlock.find_by(key: "home.about.title").update!(value_pl: "O mnie")

      patch admin_content_blocks_path, params: { section: "home.hero", fields: { title: { pl: "Tytuł" } } }

      expect(ContentBlock.find_by(key: "home.about.title").value_pl).to eq("O mnie")
    end

    it "ignores fields that do not belong to the submitted section" do
      patch admin_content_blocks_path, params: {
        section: "home.process",
        fields: { title: { pl: "Proces" }, subtitle: { pl: "nie nalezy" } }
      }

      expect(ContentBlock.find_by(key: "home.process.title").value_pl).to eq("Proces")
      expect(ContentBlock.find_by(key: "home.hero.subtitle").body_pl).to be_blank
      expect(ContentBlock.find_by(key: "home.packages.subtitle").body_pl).to be_blank
    end

    it "404s on an unknown section" do
      patch admin_content_blocks_path, params: { section: "nope.nope", fields: { title: { pl: "x" } } }

      expect(response).to have_http_status(:not_found)
    end

    it "can clear one language without touching the other" do
      block = ContentBlock.find_by(key: "home.hero.title")
      block.update!(value_pl: "Tytuł", value_en: "Title")

      patch admin_content_blocks_path, params: { section: "home.hero", fields: { title: { pl: "Tytuł", en: "" } } }

      block.reload
      expect(block.value_pl).to eq("Tytuł")
      expect(block.translated?(:en)).to be false
    end
  end
end
