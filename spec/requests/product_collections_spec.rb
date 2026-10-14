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
    expect(stories).to have_css("h3 a[href='#{product_path(story)}']", text: story.name)
    expect(programs).not_to have_text(story.name)
    expect(stories).not_to have_text(first.name)
    expect(page).not_to have_text("Szkic")
    expect(page).to have_css("section#packages", text: "Pomoc indywidualna")
    expect(page.all("main section[id]").map { |section| section[:id] }).to eq(%w[audio-processes stories packages])
    %w[audio-processes stories packages].each do |anchor|
      expect(page).to have_link(href: "##{anchor}")
      expect(page.find("##{anchor}")[:"aria-labelledby"]).to eq("#{anchor}-title")
    end
  end

  it "caps each small collection independently" do
    create_product(kind: :audio_process)
    4.times { |i| create_product(name: "Bajka #{i}") }

    get products_path

    page = Capybara.string(response.body)
    expect(page.find("#audio-processes")).to have_css('div[class*="sm:max-w-[320px]"]')
    expect(page.find("#stories")).not_to have_css('div[class*="sm:max-w-[320px]"]')
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
    expect(details[:href]).to eq(product_path(product))
    expect(details[:"aria-label"]).to eq("Zobacz szczegóły — #{product.name}")

    get product_path(product)
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
