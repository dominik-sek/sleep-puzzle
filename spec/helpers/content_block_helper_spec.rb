require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe "#content_block" do
    before { ContentBlock.sync! }

    it "renders a plain field as a bare string, with no trix wrapper" do
      ContentBlock.find_by(key: "home.hero.title").update!(value_pl: "Tytuł")

      expect(helper.content_block("home.hero.title")).to eq("Tytuł")
    end

    it "renders a rich field as Action Text" do
      ContentBlock.find_by(key: "home.hero.subtitle").update!(body_pl: "<div>Podtytuł</div>")

      expect(helper.content_block("home.hero.subtitle").body.to_html).to include("Podtytuł")
    end

    it "falls back to the default locale when a translation is empty" do
      ContentBlock.find_by(key: "home.hero.title").update!(value_pl: "Tytuł")

      expect(helper.content_block("home.hero.title", locale: :en)).to eq("Tytuł")
    end

    it "prefers the requested locale when it is filled in" do
      ContentBlock.find_by(key: "home.hero.title").update!(value_pl: "Tytuł", value_en: "Title")

      expect(helper.content_block("home.hero.title", locale: :en)).to eq("Title")
    end

    it "raises on an unknown key in development and test" do
      expect { helper.content_block("home.hero.nope") }.to raise_error(ArgumentError, /home.hero.nope/)
    end

    it "flags an empty block instead of rendering nothing" do
      expect(helper.content_block("home.hero.title")).to include("brak treści")
    end

    it "loads every block in a single query no matter how many are rendered" do
      ContentBlock.find_by(key: "home.hero.title").update!(value_pl: "Tytuł")

      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name].to_s =~ /SCHEMA|TRANSACTION/ }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        ContentBlock::Registry.keys.each { |key| helper.content_block(key) }
      end

      expect(queries).to be <= 3 # content_blocks + its two rich-text preloads
    end
  end
end
