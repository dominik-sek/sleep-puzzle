require 'rails_helper'

RSpec.describe "Audio process collection", type: :request do
  before do
    allow(PaddlePriceCatalogService).to receive(:call)
      .and_return([ paddle_price(id: "pri_456") ])
  end

  it "lists every published program in catalogue order, excluding stories, drafts and missing recordings" do
    second = create_product(name: "Drugi proces", kind: :audio_process, position: 2)
    first = create_product(name: "Pierwszy proces", kind: :audio_process, position: 1)
    create_product(name: "Bajka", kind: :bedtime_story)
    create_product(name: "Szkic", kind: :audio_process, published: false)
    missing = create_product(name: "Bez nagrania", kind: :audio_process)
    missing.audio_chapters.update_all(cdn_path: nil)

    [ :pl, :en ].each do |locale|
      get audio_processes_path(locale: locale == :en ? :en : nil)

      page = Capybara.string(response.body)
      expect(response).to have_http_status(:ok)
      links = page.all("main h2 a")
      expect(links.map(&:text)).to eq([ first.name, second.name ])
      expect(links.map { |link| link[:href] }).to eq([ first, second ].map { |p| catalogue_product_path(p, locale: locale == :en ? :en : nil) })
      expect(page).to have_button("Dodaj do koszyka", count: 2) if locale == :pl
      expect(page).to have_link(href: products_path(locale: locale == :en ? :en : nil))
      expect(page).not_to have_text("Bajka")
      expect(page).not_to have_text("Szkic")
      expect(page).not_to have_text("Bez nagrania")
      expect(page).not_to have_css("main video, main .audio-includes")
    end
  end

  it "serves each program's detailed content at its typed slug URL" do
    product = create_product(name: "Proces dla rodziców", kind: :audio_process,
                             long_description: "Dla zmęczonych rodziców.", includes: [ "Program", "Tematy" ])
    create_product(name: "Inny proces", kind: :audio_process)

    get catalogue_product_path(product)

    page = Capybara.string(response.body)
    expect(response).to have_http_status(:ok)
    expect(page).to have_css("main h1", text: product.name)
    expect(page).to have_text("Dla zmęczonych rodziców.")
    expect(page).to have_css(".audio-includes", text: "Tematy", visible: :all)
    expect(page).to have_text("Odsłuch online, bez pobierania")
  end

  it "labels the chapter region correctly in both languages on the individual product" do
    product = create_product(kind: :audio_process)

    [ :pl, :en ].each do |locale|
      get catalogue_product_path(product, locale: locale == :en ? :en : nil)

      page = Capybara.string(response.body)
      heading = page.find("h2", text: I18n.t("products.chapters.title", locale: locale))
      region = page.find("section[aria-labelledby='#{heading[:id]}']")
      expect(region).to have_css("h2##{heading[:id]}")
      expect(region).to have_css("ol li", count: 1)
      expect(heading[:id]).to eq("chapter_outline_heading_product_#{product.id}")
    end
  end

  it "keeps incomplete programs discoverable without enabling a purchase or showing partial total duration" do
    product = create_product(name: "Pełny proces", kind: :audio_process, expected_chapter_count: 24,
                             includes: [ "24 nagrania" ])

    [ audio_processes_path, catalogue_product_path(product), products_path ].each do |path|
      get path

      page = Capybara.string(response.body)
      expect(page).not_to have_button("Dodaj do koszyka")
      expect(page).to have_text("Pełny program nie jest jeszcze dostępny do zakupu")
      expect(page).not_to have_text("10 min")
    end

    get audio_processes_path
    expect(Capybara.string(response.body)).to have_link(product.name, href: catalogue_product_path(product))

    [ :pl, :en ].each do |locale|
      get catalogue_product_path(product, locale: locale == :en ? :en : nil)
      page = Capybara.string(response.body)
      expect(page).to have_css("h2", text: I18n.t("products.chapters.preview_title", locale: locale))
      expect(page).to have_css(".audio-includes", text: "24 nagrania", visible: :all)
    end
  end

  it "does not silently confirm a legacy program without a declared count" do
    create_product(kind: :audio_process, expected_chapter_count: nil)

    get audio_processes_path

    page = Capybara.string(response.body)
    expect(page).not_to have_button("Dodaj do koszyka")
    expect(page).to have_text("Pełny program nie jest jeszcze dostępny do zakupu")
  end

  it "does not hide other programs when one price is unavailable" do
    create_product(name: "Bez ceny", kind: :audio_process, paddle_price_id: "pri_missing")
    priced = create_product(name: "Z ceną", kind: :audio_process)

    get audio_processes_path

    page = Capybara.string(response.body)
    expect(page).to have_link("Bez ceny")
    expect(page).to have_link(priced.name, href: catalogue_product_path(priced))
    expect(page).to have_button("Dodaj do koszyka", count: 1)
  end

  it "keeps the account route for a purchased program when new sales are paused" do
    product = create_product(kind: :audio_process)
    user = User.create!(email: "listener@example.com", password: "password123")
    user.orders.create!(status: :paid, order_items: [ OrderItem.new(product: product) ])
    product.update!(expected_chapter_count: nil)
    sign_in user

    get audio_processes_path

    page = Capybara.string(response.body)
    expect(page).to have_link(href: dashboard_index_path(anchor: "product_#{product.id}"))
    expect(page).not_to have_button("Dodaj do koszyka")
  end

  it "formats legacy includes on the individual product without losing the topic disclosure" do
    product = create_product(kind: :audio_process, includes: [ "Wstęp do procesu", "**Program**", "- **Siedem** nagrań", "- Plan działania" ])

    get catalogue_product_path(product)

    page = Capybara.string(response.body)
    expect(page).to have_css(".trix-content p", text: "Wstęp do procesu")
    expect(page).to have_css("details .trix-content li strong", text: "Siedem", visible: :all)
    expect(response.body).not_to include("**Siedem**")
  end

  it "shows a localized empty state with a route back to the shop" do
    create_product(kind: :bedtime_story)

    [ :pl, :en ].each do |locale|
      get audio_processes_path(locale: locale == :en ? :en : nil)

      page = Capybara.string(response.body)
      text = locale == :en ? "Audio processes will appear here soon." : "Audioprocesy pojawią się tutaj wkrótce."
      expect(page).to have_text(text)
      expect(page).to have_css("main a[href='#{products_path(locale: locale == :en ? :en : nil)}']")
      expect(page).not_to have_css("main h2 a")
    end
  end
end
