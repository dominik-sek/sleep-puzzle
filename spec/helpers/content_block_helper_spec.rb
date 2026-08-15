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

        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
          ContentBlock::Registry.keys.each { |key| helper.content_block(key) }
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
end
