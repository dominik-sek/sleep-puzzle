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

    it "lists every visible section for search and renders one section form" do
      get admin_content_blocks_path

      expect(response).to have_http_status(:ok)
      document = Capybara.string(response.body)
      ContentBlock::Registry.pages.each do |registry_page|
        expect(response.body).to include(registry_page.label)
        registry_page.sections.reject(&:admin_hidden?).each do |section|
          expect(response.body).to include(%(href="#{admin_content_blocks_path(open: section.full_key)}"))
        end
      end
      expect(document).to have_css('form [name="section"][value="home.hero"]', count: 1, visible: :all)
      expect(document).to have_no_css('form [name="section"][value="home.about"]', visible: :all)
    end

    it "hides retired home controls while keeping their saved content" do
      ContentBlock.find_by!(key: "home.about.body").update!(value_pl: "Zachowany opis")

      get admin_content_blocks_path(open: "home.about")

      page = Capybara.string(response.body)
      %w[stats process packages audio newsletter].each do |section|
        expect(page).to have_no_css(%([id="section-home-#{section}"]))
      end
      expect(page).to have_no_css('#section-home-about [name="fields[body][pl]"]')
      expect(page).to have_no_css('#section-home-about [name^="fields[cta_"]')
      expect(page).to have_no_css('#section-home-closing [name="fields[cta][pl]"]')
      expect(response.body).not_to include("Zachowany opis")
      preview = JSON.parse(page.find('[data-controller="content-blocks"]')["data-content-blocks-pages-value"])
      expect(preview.dig("home", "pl", "entries").map { |entry| entry["key"] }).not_to include("home.about.body", "home.closing.cta")
      expect(ContentBlock.find_by!(key: "home.about.body").value_pl).to eq("Zachowany opis")
    end

    it "embeds the selected public page and exposes its current copy for the live preview" do
      ContentBlock.find_by!(key: "about.intro.name").update!(value_pl: "Nowa Karola")

      get admin_content_blocks_path(open: "about.intro")

      page = Capybara.string(response.body)
      preview = page.find('[data-controller="content-blocks"]')
      data = JSON.parse(preview["data-content-blocks-pages-value"])

      expect(preview["data-content-blocks-page-value"]).to eq("about")
      expect(page).to have_css('iframe[title="Podgląd strony"][sandbox="allow-same-origin"]:not([src])', visible: :all)
      expect(page).to have_css('#content-preview[hidden]', visible: :all)
      expect(data.dig("about", "en", "url")).to eq("/en/about")
      expect(data.dig("about", "pl", "entries")).to include(include("key" => "about.intro.name", "text" => "Nowa Karola"))
      expect(page).to have_css('[data-preview-section="about.intro"] button', text: "Pokaż na stronie")
    end

    it "matches preview text containing HTML entities with visible page text" do
      get admin_content_blocks_path(open: "about.certifications")

      data = JSON.parse(Capybara.string(response.body).find('[data-controller="content-blocks"]')["data-content-blocks-pages-value"])
      title = data.dig("about", "en", "entries").find { |entry| entry["key"] == "about.certifications.title" }
      expect(title["text"]).to eq("Certifications & qualifications")
    end

    it "selects a single section from a page and keeps deep links" do
      get admin_content_blocks_path(page: "packages")
      page = Capybara.string(response.body)
      expect(page).to have_css('form [name="section"][value="packages.collaboration"]', count: 1, visible: :all)
      expect(page).to have_css('#section-packages-collaboration')
      expect(page).to have_no_css('#section-home-hero')

      get admin_content_blocks_path(open: "about.certifications")
      page = Capybara.string(response.body)
      expect(page).to have_css('form [name="section"][value="about.certifications"]', count: 1, visible: :all)
      expect(page).to have_css('#section-about-certifications')
    end

    it "keeps both languages in the selected form while showing one tab" do
      get admin_content_blocks_path(open: "home.about", lang: "en")

      rich = ContentBlock::Registry.section("home.about").fields.count { |field| field.rich? && !field.admin_hidden? }
      expect(response.body.scan("<trix-editor").size).to eq(rich * ContentBlock::LOCALES.size)
      expect(response.body).to include(%(name="fields[title][pl]"))
      expect(response.body).to include(%(name="fields[title][en]"))
      page = Capybara.string(response.body)
      expect(page).to have_css('[data-lang="pl"][hidden]', visible: :all)
      expect(page).to have_css('[data-lang="en"]:not([hidden])', visible: :all)
      expect(page).to have_css('[name="lang"][value="en"]', visible: :all)
    end

    it "selects the first visible home section by default" do
      get admin_content_blocks_path

      expect(response.body).to include(%(data-content-blocks-section-value="home.hero"))
    end

    it "selects the requested section" do
      get admin_content_blocks_path(open: "home.methodology")

      expect(response.body).to include(%(data-content-blocks-section-value="home.methodology"))
    end

    it "does not select a hidden section requested directly" do
      get admin_content_blocks_path(open: "home.process")

      expect(response.body).to include(%(data-content-blocks-section-value="home.hero"))
      expect(response.body).not_to include(%(data-content-blocks-section-value="home.process"))
    end

    it "ignores an unknown section in ?open=" do
      get admin_content_blocks_path(open: "nope.nope")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(data-content-blocks-section-value="home.hero"))
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

    it "returns to the English tab after saving from it" do
      patch admin_content_blocks_path, params: {
        section: "home.hero", lang: "en", fields: { title: { en: "Title" } }
      }

      expect(response).to redirect_to(admin_content_blocks_path(open: "home.hero", lang: "en"))
    end

    it "saves rich fields as Action Text" do
      hidden_button = ContentBlock.find_by!(key: "home.about.cta_label")
      hidden_button.update!(value_pl: "Zachowany przycisk")

      patch admin_content_blocks_path, params: {
        section: "home.about",
        fields: { lead: { pl: "<div>Wstęp</div>", en: "<div>Lead</div>" } }
      }

      block = ContentBlock.find_by(key: "home.about.lead")
      expect(block.body_pl.body.to_html).to include("Wstęp")
      expect(block.body_en.body.to_html).to include("Lead")
      expect(block.value_pl).to be_nil
      expect(hidden_button.reload.value_pl).to eq("Zachowany przycisk")
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
    # The panel builds its tree from the registry, so a field added to the YAML is
    # editable before anyone runs content_blocks:sync. It used to 404 on save.
    context "when the section has never been synced" do
      it "saves a field that has no row yet" do
        ContentBlock.where(key: "home.hero.title").delete_all

        patch admin_content_blocks_path,
              params: { section: "home.hero", fields: { title: { pl: "Tytuł", en: "Title" } } }

        expect(response).to redirect_to(admin_content_blocks_path(open: "home.hero"))
        expect(ContentBlock.find_by(key: "home.hero.title").value_pl).to eq("Tytuł")
      end

      it "keeps the rest of the section's edits when one field is missing its row" do
        ContentBlock.where(key: "home.hero.subtitle").delete_all

        patch admin_content_blocks_path, params: {
          section: "home.hero",
          fields: { title: { pl: "Nowy tytuł" }, subtitle: { pl: "Nowy podtytuł" } }
        }

        expect(ContentBlock.find_by(key: "home.hero.title").value_pl).to eq("Nowy tytuł")
        expect(ContentBlock.find_by(key: "home.hero.subtitle").value_pl).to eq("Nowy podtytuł")
      end
    end
  end

  describe "image blocks" do
    before { sign_in admin }

    let(:photo) { fixture_file_upload("photo.png", "image/png") }
    let(:block) { ContentBlock.find_by!(key: "home.about.photo") }

    def upload(file, extra = {})
      patch admin_content_blocks_path,
            params: { section: "home.about", images: { "photo" => { "file" => file }.merge(extra) } }
    end

    it "renders a file input rather than a Polish/English pair" do
      get admin_content_blocks_path(open: "home.about")

      expect(response.body).to include(%(name="images[photo][file]"))
      expect(response.body).not_to include(%(name="fields[photo][pl]"))
    end

    it "posts the section form as multipart, or the upload never arrives" do
      get admin_content_blocks_path

      expect(response.body).to include('enctype="multipart/form-data"')
    end

    it "attaches an uploaded picture" do
      ContentBlock.sync!

      expect { upload(photo) }.to change { block.reload.image.attached? }.from(false).to(true)
      expect(flash[:notice]).to be_present
    end

    it "replaces the picture already there" do
      ContentBlock.sync!
      upload(photo)
      first_blob = block.reload.image.blob.id

      upload(fixture_file_upload("photo.png", "image/png"))

      expect(block.reload.image.blob.id).not_to eq(first_blob)
    end

    it "removes the picture when asked" do
      ContentBlock.sync!
      upload(photo)

      patch admin_content_blocks_path,
            params: { section: "home.about", images: { "photo" => { "remove" => "1" } } }

      expect(block.reload.image.attached?).to be(false)
    end

    # checked before attaching, so a refused file leaves nothing behind
    it "refuses a file that is not an image, and says why" do
      ContentBlock.sync!

      upload(fixture_file_upload("not-an-image.txt", "text/plain"))

      expect(block.reload.image.attached?).to be(false)
      expect(flash[:alert]).to include("nie jest obsługiwanym obrazem")
    end

    it "refuses a file over the size limit" do
      ContentBlock.sync!
      stub_const("ContentBlock::IMAGE_MAX_BYTES", 1)

      upload(photo)

      expect(block.reload.image.attached?).to be(false)
      expect(flash[:alert]).to include("jest za duży")
    end

    # the copy in the same section saved fine; only the file was wrong
    it "keeps the text it saved alongside a refused upload" do
      ContentBlock.sync!

      patch admin_content_blocks_path,
            params: {
              section: "home.about",
              fields: { "title" => { "pl" => "Nowy tytuł", "en" => "" } },
              images: { "photo" => { "file" => fixture_file_upload("not-an-image.txt", "text/plain") } }
            }

      expect(ContentBlock.find_by(key: "home.about.title").value_pl).to eq("Nowy tytuł")
      expect(flash[:alert]).to be_present
    end

    context "when the field has never been synced" do
      it "attaches an image to a field that has no row yet" do
        ContentBlock.where(key: "home.about.photo").delete_all

        patch admin_content_blocks_path,
              params: { section: "home.about", images: { "photo" => { "file" => photo } } }

        expect(ContentBlock.find_by(key: "home.about.photo").image).to be_attached
      end
    end

    it "ignores an image posted for a section that does not declare it" do
      ContentBlock.sync!

      patch admin_content_blocks_path,
            params: { section: "home.hero", images: { "photo" => { "file" => photo } } }

      expect(block.reload.image.attached?).to be(false)
    end
  end
end
