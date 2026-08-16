require 'rails_helper'

RSpec.describe "Home", type: :request do
  # The state a fresh deploy is in: migrations run, nothing seeded, nobody has
  # opened the admin panel yet. The page must still render its real copy.
  context "with an empty database" do
    it "renders every content block from its declared default" do
      expect(ContentBlock.count).to eq(0)

      get root_path

      expect(response).to have_http_status(:ok)
      # this page's own fields: the registry also declares the other pages'
      home_fields = ContentBlock::Registry.fields.select { |field| field.section.page.key == "home" }

      home_fields.each do |field|
        default = field.default_for(:pl)
        next if default.blank?

        expect(response.body).to include(default.gsub(%r{</?div>}, "").strip.first(40))
      end
    end

    it "shows no missing-content markers" do
      get root_path

      expect(response.body).not_to include("brak treści")
    end
  end

  context "once blocks are seeded but still empty" do
    before { ContentBlock.sync! }

    it "still falls back to the defaults" do
      get root_path

      expect(response.body).to include("Układamy sen Twojej rodziny jak puzzle.")
    end
  end

  describe "owner-managed lists" do
    it "falls back to the declared defaults when the database has none" do
      expect(ContentItem.count).to eq(0)

      get root_path

      expect(response.body).to include("20+ lat")
      expect(response.body).to include("Krok pierwszy", "Krok drugi", "Krok trzeci")
    end

    it "prefixes each stat with the astroid icon" do
      get root_path

      stats = response.body[/<ul class="flex flex-wrap items-center justify-center.*?<\/ul>/m]
      expect(stats).to be_present
      expect(stats.scan("<svg").size).to eq(1)
    end

    it "renders the owner's items once there are any, instead of the defaults" do
      %w[Pierwszy Drugi].each_with_index do |title, index|
        item = ContentItem.create!(collection_key: "home.process", position: index + 1)
        item.assign_value("title", :pl, title)
        item.save!
      end

      get root_path

      expect(response.body).to include("Pierwszy", "Drugi")
      expect(response.body).not_to include("Krok pierwszy")
    end

    it "numbers steps by display order rather than storing the number" do
      second = ContentItem.create!(collection_key: "home.process", position: 5)
      second.assign_value("title", :pl, "Później"); second.save!
      first = ContentItem.create!(collection_key: "home.process", position: 1)
      first.assign_value("title", :pl, "Najpierw"); first.save!

      get root_path

      expect(response.body.index("Najpierw")).to be < response.body.index("Później")
    end

    it "lets the owner add more stats than the default single one" do
      [ "20+ lat", "500+ rodzin" ].each_with_index do |text, index|
        item = ContentItem.create!(collection_key: "home.stats", position: index + 1)
        item.assign_value("text", :pl, text)
        item.save!
      end

      get root_path

      expect(response.body).to include("20+ lat", "500+ rodzin")
    end
  end

  context "once a block has been edited" do
    before { ContentBlock.sync! }

    it "shows the edited copy instead of the default" do
      ContentBlock.find_by(key: "home.hero.title").update!(value_pl: "Zupełnie nowy nagłówek")

      get root_path

      expect(response.body).to include("Zupełnie nowy nagłówek")
      expect(response.body).not_to include("Układamy sen Twojej rodziny jak puzzle.")
    end

    it "renders edited rich text through the trix-content wrapper" do
      ContentBlock.find_by(key: "home.about.lead").update!(body_pl: "<div>Nowy <strong>wstęp</strong></div>")

      get root_path

      expect(response.body).to include("Nowy <strong>wstęp</strong>")
      expect(response.body).to include("trix-content")
    end
  end

  describe "the packages section" do
    it "renders the published packages in position order" do
      create_package(name: "Drugi pakiet", position: 2, duration: 6)
      create_package(name: "Pierwszy pakiet", position: 1, duration: 4)

      get root_path

      expect(response.body).to include("Pierwszy pakiet", "Drugi pakiet")
      expect(response.body.index("Pierwszy pakiet")).to be < response.body.index("Drugi pakiet")
      expect(response.body).to include("Czas trwania wsparcia: 4 tygodnie")
    end

    it "leaves out an unpublished package" do
      create_package(name: "Szkic", published: false)

      get root_path

      expect(response.body).not_to include("Szkic")
    end

    it "renders in English once a package has been translated" do
      create_package(name: "Szybka ulga", name_en: "Quick relief")

      I18n.with_locale(:en) { get root_path }

      expect(response.body).to include("Quick relief")
    end

    # falling back is the point of storing both languages in one place
    it "falls back to Polish for a package with no English version" do
      create_package(name: "Szybka ulga")

      I18n.with_locale(:en) { get root_path }

      expect(response.body).to include("Szybka ulga")
    end
  end

  describe "the audio section" do
    it "renders published products with their kind" do
      create_product(name: "Bajka o sowie", kind: :bedtime_story)

      get root_path

      expect(response.body).to include("Bajka o sowie", "Bajka na dobranoc")
    end

    it "leaves out an unpublished product" do
      create_product(name: "Szkic", published: false)

      get root_path

      expect(response.body).not_to include("Szkic")
    end
  end
end
