require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe "#content_block" do
    context "with nothing in the database at all" do
      # the state a fresh deploy is in, before seeds or any edit
      it "renders the declared default for a plain field" do
        expect(helper.content_block("home.hero.title"))
          .to eq(ContentBlock::Registry.field("home.hero.title").default_for(:pl))
      end

      it "renders the declared default for a rich field, in the same wrapper as stored content" do
        output = helper.content_block("home.about.lead")

        expect(output).to have_css("div.trix-content")
        expect(output).to include("Nazywam się Karola")
      end

      it "falls back to the pl default when asked for a locale with no default of its own" do
        expect(helper.content_block("home.hero.title", locale: :en))
          .to eq(ContentBlock::Registry.field("home.hero.title").default_for(:pl))
      end

      it "does not query per block" do
        queries = 0
        counter = ->(*, payload) { queries += 1 unless payload[:name].to_s =~ /SCHEMA|TRANSACTION/ }

        # text blocks only: an image block holds a file, and content_image is
        # the way to reach it
        text_keys = ContentBlock::Registry.fields.select(&:translatable?).map(&:full_key)

        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
          text_keys.each { |key| helper.content_block(key) }
        end

        expect(queries).to be <= 3
      end
    end

    context "once a block has been edited" do
      before { ContentBlock.sync! }

      it "prefers the stored value over the default" do
        ContentBlock.find_by(key: "home.hero.title").update!(value_pl: "Nowy tytuł")

        expect(helper.content_block("home.hero.title")).to eq("Nowy tytuł")
      end

      it "renders a stored rich field as Action Text" do
        ContentBlock.find_by(key: "home.about.lead").update!(body_pl: "<div>zapisane</div>")

        expect(helper.content_block("home.about.lead").body.to_html).to include("zapisane")
      end

      it "falls back to the default locale before falling back to the declared default" do
        ContentBlock.find_by(key: "home.hero.title").update!(value_pl: "Tylko polski")

        expect(helper.content_block("home.hero.title", locale: :en)).to eq("Tylko polski")
      end

      it "prefers the requested locale when it is filled in" do
        ContentBlock.find_by(key: "home.hero.title").update!(value_pl: "Polski", value_en: "English")

        expect(helper.content_block("home.hero.title", locale: :en)).to eq("English")
      end
    end

    it "raises on an unknown key in development and test" do
      expect { helper.content_block("home.hero.nope") }.to raise_error(ArgumentError, /home.hero.nope/)
    end

    it "flags a block that has neither stored content nor a default" do
      field = ContentBlock::Registry.field("home.hero.title")
      allow(field).to receive(:default_for).and_return(nil)
      allow(ContentBlock::Registry).to receive(:field).with("home.hero.title").and_return(field)

      expect(helper.content_block("home.hero.title")).to include("brak treści")
    end
  end

  describe "#content_image" do
    let(:block) { ContentBlock.find_by!(key: "home.about.photo") }

    before { ContentBlock.sync! }

    # unlike a text block there is no default to fall back to, so the template
    # decides what an empty slot looks like
    it "is nil when nothing has been uploaded" do
      expect(helper.content_image("home.about.photo")).to be_nil
    end

    it "renders the uploaded picture" do
      block.image.attach(io: file_fixture("photo.png").open, filename: "photo.png", content_type: "image/png")

      expect(helper.content_image("home.about.photo")).to include("<img")
    end

    it "passes attributes through to the tag" do
      block.image.attach(io: file_fixture("photo.png").open, filename: "photo.png", content_type: "image/png")

      expect(helper.content_image("home.about.photo", alt: "Karola", class: "rounded")).to include('alt="Karola"', 'class="rounded"')
    end

    it "rejects a key that is not an image block" do
      expect { helper.content_image("home.about.title") }.to raise_error(ArgumentError, /not an image/)
    end

    it "rejects a text block asked for through content_block" do
      expect { helper.content_block("home.about.photo") }.to raise_error(ArgumentError, /image block/)
    end
  end

  describe "#content_link_url" do
    before { ContentBlock.sync! }

    def set_url(value)
      ContentBlock.find_by!(key: "home.about.cta_url").update!(value_pl: value)
    end

    it "passes an absolute web address through" do
      set_url("https://instagram.com/karola")

      expect(helper.content_link_url("home.about.cta_url")).to eq("https://instagram.com/karola")
    end

    it "passes a path or anchor through" do
      set_url("/kontakt")
      expect(helper.content_link_url("home.about.cta_url")).to eq("/kontakt")
    end

    it "passes a mailto through" do
      set_url("mailto:karola@example.com")

      expect(helper.content_link_url("home.about.cta_url")).to eq("mailto:karola@example.com")
    end

    # admin-only, so this is about a mistyped value rather than an attack
    it "falls back for anything that is not an ordinary link target" do
      set_url("javascript:alert(1)")

      expect(helper.content_link_url("home.about.cta_url")).to eq("#")
    end

    it "falls back for a scheme-less host, which would otherwise read as a path" do
      set_url("instagram.com/karola")

      expect(helper.content_link_url("home.about.cta_url")).to eq("#")
    end
  end
end
