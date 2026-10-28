require "rails_helper"

RSpec.describe "Shop collections", type: :request do
  before do
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456") ])
  end

  it "groups by kind while preserving each category's catalogue order and product URLs" do
    story = create_product(name: "Bajka pierwsza", position: 0)
    second = create_product(name: "Drugi proces", kind: :audio_process, position: 2)
    first = create_product(name: "Pierwszy proces", kind: :audio_process, position: 1)
    create_product(name: "Szkic", published: false)
    create_package(name: "Pomoc indywidualna")

    get products_path

    page = Capybara.string(response.body)
    programs = page.find("section#audio-processes")
    stories = page.find("section#stories")
    expect(programs.all("h3 a").map(&:text)).to eq([ first.name, second.name ])
    expect(stories).to have_css("h3 a[href='#{catalogue_product_path(story)}']", text: story.name)
    expect(programs).not_to have_text(story.name)
    expect(stories).not_to have_text(first.name)
    expect(page).not_to have_text("Szkic")
    expect(page).to have_css("section#packages", text: "Pomoc indywidualna")
    expect(page.all("main section[id]").map { |section| section[:id] }).to eq(%w[packages audio-processes stories])
    expect(page).not_to have_css("main nav")
    %w[audio-processes stories packages].each do |anchor|
      expect(page.find("##{anchor}")[:"aria-labelledby"]).to eq("#{anchor}-title")
    end
  end

  it "gives a single audioprocess the full shelf while keeping story cards" do
    create_product(kind: :audio_process)
    4.times { |i| create_product(name: "Bajka #{i}") }

    get products_path

    page = Capybara.string(response.body)
    expect(page.find("#audio-processes")).to have_css(".shop-shelf-single article", count: 1)
    expect(page).not_to have_css('[data-controller="product-shelf"]')
    expect(page.find("#stories")).not_to have_css('div[class*="sm:max-w-[320px]"]')
  end

  [ 2, 3, 4, 6 ].each do |count|
    it "renders #{count} audioprocesses with a rail only from four items" do
      count.times { |i| create_product(name: "Proces #{i}", kind: :audio_process) }
      get products_path

      page = Capybara.string(response.body)
      expect(page).to have_css(".shop-shelf article", count: count)
      expect(page.find(".shop-shelf")[:tabindex]).to eq("0")
      expect(page.find(".shop-shelf")[:"aria-labelledby"]).to eq("audio-processes-title")
      if count >= 4
        expect(page).to have_css('.shop-shelf-rail[data-product-shelf-target="track"]')
        expect(page).to have_css('button[aria-controls="audio-processes-track"]', count: 2, visible: :all)
      else
        expect(page).not_to have_css(".shop-shelf-rail, button[aria-controls='audio-processes-track']")
      end
    end
  end

  it "spotlights the second published package with Paddle pricing and its first highlight" do
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_123", amount: "155000") ])
    first = create_package(name: "Pierwszy", position: 1)
    featured = create_package(name: "Spokojny rytm", position: 2, duration: 5)
    featured.assign_translation_list(:highlights, :pl, [ "Plan na spokojniejsze wieczory.", "Drugi wyróżnik" ])
    featured.assign_translation(:for_whom, :pl, "Długi opis dla kogo")
    featured.save!
    last = create_package(name: "Trzeci", position: 3)
    create_package(name: "Nieopublikowany", position: 0, published: false)
    get products_path

    page = Capybara.string(response.body)
    card = page.find(".shop-package-feature")
    expect(card[:href]).to eq(packages_path(anchor: "package_#{featured.id}"))
    expect(card).to have_text("Plan na spokojniejsze wieczory.")
    expect(card).to have_text("Czas trwania wsparcia: 5 tygodni")
    expect(card).to have_text("1 550,00 PLN")
    expect(card).not_to have_text("Drugi wyróżnik")
    expect(card).not_to have_text("Długi opis dla kogo")
    expect(page.all(".shop-package-row h3").map(&:text)).to eq([ first.name, last.name ])
    expect(page).not_to have_text("Nieopublikowany")
  end

  it "keeps a lone package and unavailable prices readable without offering booking" do
    create_package(name: "Jedyny", duration: nil)
    get products_path(locale: :en)

    card = Capybara.string(response.body).find(".shop-package-feature")
    expect(card).to have_text("Price temporarily unavailable")
    expect(card).to have_text("View package")
    expect(card[:href]).to start_with("/en/packages#")
    expect(card).not_to have_css(".bg-accent, .shop-package-duration")
    expect(card).not_to have_text("See available times")
  end

  it "keeps the incomplete program note, price and outline details action together" do
    product = create_product(kind: :audio_process, expected_chapter_count: 2)
    get products_path

    card = Capybara.string(response.body).find(".shop-shelf-single article")
    expect(card).to have_text("Pełny program nie jest jeszcze dostępny do zakupu")
    expect(card).to have_text("249,00 PLN")
    expect(card).to have_link("Zobacz szczegóły", href: catalogue_product_path(product))
    expect(card).not_to have_button("Dodaj do koszyka")
  end

  it "shows a short preview in cards and preserves the complete description on the individual page" do
    description = "Początek opowieści. " + "Dalsze szczegóły opowieści. " * 20 + "Ważne zakończenie."
    product = create_product(description: description)

    get products_path
    page = Capybara.string(response.body)
    card = page.find("#stories article")
    expect(card).to have_text("Początek opowieści.")
    expect(card).not_to have_text("Ważne zakończenie.")
    details = card.find("a", text: "Zobacz szczegóły")
    expect(details[:href]).to eq(catalogue_product_path(product))
    expect(details[:"aria-label"]).to eq("Zobacz szczegóły — #{product.name}")

    get catalogue_product_path(product)
    expect(Capybara.string(response.body).find("main")).to have_text("Ważne zakończenie.")
  end

  it "retains an empty stories destination while published programs remain visible" do
    create_product(name: "Program", kind: :audio_process)
    ContentBlock.create!(key: "shop.collections.stories_empty", value_pl: "Nowe bajki przygotowuję dla Was.")

    get products_path
    page = Capybara.string(response.body)
    expect(page).to have_css("#stories", text: "Nowe bajki przygotowuję dla Was.")
    expect(page).to have_css("#audio-processes h3", text: "Program")
    expect(page).not_to have_css("#stories article")
  end
end
