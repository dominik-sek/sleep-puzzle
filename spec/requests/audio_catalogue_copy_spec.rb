require "rails_helper"

RSpec.describe "Audio catalogue language", type: :request do
  it "uses the same editable delivery and access facts on stories and product pages" do
    ContentBlock.create!(key: "shop.product.format_value", value_pl: "Odsłuch w Twojej bibliotece")
    ContentBlock.create!(key: "shop.product.access_value", value_pl: "Dostęp zgodnie z opisem oferty")
    program = create_product(kind: :audio_process)
    story = create_product(kind: :bedtime_story)

    [ stories_path, catalogue_product_path(program), catalogue_product_path(story) ].each do |path|
      get path

      page = Capybara.string(response.body)
      expect(page).to have_css("main dl dd", text: "Odsłuch w Twojej bibliotece"), path
      expect(page).to have_css("main dl dd", text: "Dostęp zgodnie z opisem oferty"), path
    end
  end

  it "links Polish and English readers directly to the stories category" do
    [ [ nil, "Bajki audio", "Audioprocesy" ], [ :en, "Audio stories", "Audio processes" ] ].each do |locale, stories, programs|
      get products_path(locale: locale)

      page = Capybara.string(response.body)
      expect(page).to have_link(stories, href: stories_path(locale: locale))
      expect(page).to have_link(programs, href: audio_processes_path(locale: locale))
      expect(page).to have_css("section#stories h2", text: stories)
    end
  end
end
