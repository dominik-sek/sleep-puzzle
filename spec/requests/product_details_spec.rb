require "rails_helper"

RSpec.describe "Product detail variants", type: :request do
  before do
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456") ])
  end

  %i[audio_process bedtime_story].each do |kind|
    [ nil, :en ].each do |locale|
      it "returns #{kind} to its collection and suggests only the same kind in #{locale || :pl}" do
        product = create_product(kind: kind, name: "Główny")
        later = create_product(kind: kind, name: "Późniejszy", position: 3)
        earlier = create_product(kind: kind, name: "Wcześniejszy", position: 1)
        create_product(kind: kind, name: "Szkic", published: false)
        create_product(kind: kind == :audio_process ? :bedtime_story : :audio_process, name: "Inny rodzaj")
        key = kind == :audio_process ? "processes" : "stories"
        ContentBlock.create!(key: "shop.product.back_#{key}", value_pl: "Powrót do kolekcji")
        ContentBlock.create!(key: "shop.product.more_#{key}", value_pl: "Polecane nagrania")

        get product_path(product, locale: locale)

        page = Capybara.string(response.body)
        collection = kind == :audio_process ? audio_process_path(locale: locale) : stories_path(locale: locale)
        expect(page.find("main nav")).to have_link("Powrót do kolekcji", href: collection)
        expect(page.find("main nav")).to have_link(href: products_path(locale: locale))
        related = page.find("section[aria-labelledby='related-products-title']")
        expect(related).to have_css("h2", text: "Polecane nagrania")
        expect(related.all("a").map { |link| link[:href] }).to eq([ earlier, later ].map { |other| product_path(other, locale: locale) })
        expect(related).not_to have_text("Inny rodzaj")
        expect(related).not_to have_text("Szkic")
      end
    end

    it "hides recommendations for #{kind} when only the other kind exists" do
      product = create_product(kind: kind)
      create_product(kind: kind == :audio_process ? :bedtime_story : :audio_process)

      get product_path(product)

      expect(Capybara.string(response.body)).not_to have_css("#related-products-title")
    end
  end

  it "keeps each program's suitability and full topics on its own detail page before the recording outline" do
    first = create_product(kind: :audio_process, name: "Pierwszy proces",
      long_description: "Dla rodziców potrzebujących wsparcia.", includes: [ "Wprowadzenie", "- Pierwszy temat" ])
    second = create_product(kind: :audio_process, name: "Drugi proces",
      long_description: "Dla rodziców szukających innych tematów.", includes: [ "Krótki opis", "- Drugi temat" ])

    [ first, second ].each do |product|
      get product_path(product)

      page = Capybara.string(response.body)
      expect(response).to have_http_status(:ok)
      expect(page).to have_css("h1", text: product.name)
      expect(page).to have_css("section[aria-labelledby='suitability_heading_product_#{product.id}']", text: product.long_description)
      expect(page).to have_css("details summary[aria-labelledby='includes_toggle_product_#{product.id} includes_heading_product_#{product.id}']")
      headings = page.all("main h2").map(&:text)
      expect(headings.first(3)).to eq([ "Dla kogo", "Co obejmuje", "Program audioprocesu" ])
      other = product == first ? second : first
      expect(page.find("main")).not_to have_text(other.long_description)
    end
  end

  it "does not add empty suitability or topic sections to an unwritten program" do
    product = create_product(kind: :audio_process)

    get product_path(product)

    page = Capybara.string(response.body)
    expect(page).not_to have_css("section[aria-labelledby^='suitability_heading_']")
    expect(page).not_to have_css("section[aria-labelledby^='includes_heading_']")
    expect(page).to have_css("h2", text: "Program audioprocesu")
  end

  it "keeps a story's description, sample and includes without program-specific sections" do
    with_bunny_cdn
    product = create_product(long_description: "Pełny opis bajki.", includes: [ "Jedno nagranie" ],
      preview_cdn_path: "/previews/story.mp3", length_minutes: 12)

    get product_path(product)

    page = Capybara.string(response.body)
    expect(page).to have_css("h2", text: "O tym nagraniu")
    expect(page).to have_css(".product-includes", text: "Jedno nagranie")
    expect(page).to have_css("audio[src='#{preview_product_path(product)}'][preload='none']")
    expect(page).not_to have_text("Dla kogo")
    expect(page).not_to have_css(".audio-includes, details")
    expect(page.find("main")).to have_text("12 min", count: 1)
  end
end
