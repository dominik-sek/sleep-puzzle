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

    # A css matcher rather than a regex: the trigger carries
    # data-action="click->accordion#toggle", and the > in that arrow breaks any
    # [^>]* attempt to scan within a single tag. Scoped to accordion items
    # because the tree's page folder is aria-expanded too, and open by design.
    OPEN_SECTION = '[data-accordion-target="item"][data-state="open"]'

    # Capybara.string because have_css(count:) needs a node, not a raw String
    def open_sections(body)
      Capybara.string(body)
    end

    it "renders every section collapsed by default" do
      get admin_content_blocks_path

      expect(open_sections(response.body)).to have_css(OPEN_SECTION, count: 0)
    end

    it "renders the requested section expanded" do
      get admin_content_blocks_path(open: "home.process")

      # opened server-side rather than by javascript: a redirect's anchor does
      # not survive Turbo following it with fetch
      expect(open_sections(response.body)).to have_css(OPEN_SECTION, count: 1)
      expect(response.body).to include(%(data-content-blocks-open-value="section-home-process"))
    end

    it "ignores an unknown section in ?open=" do
      get admin_content_blocks_path(open: "nope.nope")

      expect(response).to have_http_status(:ok)
      expect(open_sections(response.body)).to have_css(OPEN_SECTION, count: 0)
    end

    it "emits no duplicate DOM ids" do
      get admin_content_blocks_path

      ids = response.body.scan(/id="([^"]+)"/).flatten
      expect(ids).to eq(ids.uniq)
    end
  end

  describe "PATCH /admin/content_blocks" do
    before { sign_in admin }

    it "saves plain fields in both languages" do
      patch admin_content_blocks_path, params: {
        section: "home.hero",
        fields: {
          title: { pl: "Tytuł", en: "Title" },
          subtitle: { pl: "Podtytuł", en: "Subtitle" }
        }
      }

      # ?open= not an anchor: Turbo strips the fragment when following a redirect
      expect(response).to redirect_to(admin_content_blocks_path(open: "home.hero"))
      expect(ContentBlock.find_by(key: "home.hero.title").value_pl).to eq("Tytuł")
      expect(ContentBlock.find_by(key: "home.hero.title").value_en).to eq("Title")
      expect(ContentBlock.find_by(key: "home.hero.subtitle").value_pl).to eq("Podtytuł")
    end

    it "saves rich fields as Action Text" do
      patch admin_content_blocks_path, params: {
        section: "home.about",
        fields: { lead: { pl: "<div>Wstęp</div>", en: "<div>Lead</div>" } }
      }

      block = ContentBlock.find_by(key: "home.about.lead")
      expect(block.body_pl.body.to_html).to include("Wstęp")
      expect(block.body_en.body.to_html).to include("Lead")
      expect(block.value_pl).to be_nil
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
