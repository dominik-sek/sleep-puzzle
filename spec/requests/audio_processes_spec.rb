require 'rails_helper'

RSpec.describe "Audio process landing", type: :request do
  before do
    allow(PaddlePriceCatalogService).to receive(:call)
      .and_return([ paddle_price(id: "pri_456") ])
  end

  it "shows one published audio process and a route to purchase" do
    create_product(name: "Bajka", kind: :bedtime_story)
    create_product(name: "Proces dla rodziców", kind: :audio_process)

    get audio_process_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Proces dla rodziców", "Dla kogo")
    expect(response.body).not_to include("Bajka")
    expect(Capybara.string(response.body)).to have_button("Dodaj do koszyka")
  end

  it "exposes the chapter heading and links its region label to the real heading in both languages" do
    product = create_product(kind: :audio_process)

    [ :pl, :en ].each do |locale|
      get audio_process_path(locale: locale == :en ? :en : nil)

      page = Capybara.string(response.body)
      heading = page.find("h2", text: I18n.t("products.chapters.title", locale: locale))
      region = page.find("section[aria-labelledby='#{heading[:id]}']")
      expect(region).to have_css("h2##{heading[:id]}")
      expect(region).to have_css("ol li", count: 1)
      expect(region[:"aria-label"]).to be_nil
      expect(heading[:id]).to eq("chapter_outline_heading_product_#{product.id}")
    end
  end

  it "keeps the program preview visible but offers no purchase until the full declared program is ready" do
    product = create_product(kind: :audio_process, expected_chapter_count: 24,
                             includes: [ "24 nagrania" ])

    [ audio_process_path, product_path(product), products_path ].each do |path|
      get path

      page = Capybara.string(response.body)
      expect(page).not_to have_button("Dodaj do koszyka")
      expect(page).to have_text("Pełny program nie jest jeszcze dostępny do zakupu")
    end

    get audio_process_path
    expect(Capybara.string(response.body)).to have_css("h2", text: "Program audioprocesu")
    expect(response.body).to include("24 nagrania")
  end

  it "does not silently confirm a legacy program without a declared count" do
    create_product(kind: :audio_process, expected_chapter_count: nil)

    get audio_process_path

    page = Capybara.string(response.body)
    expect(page).not_to have_button("Dodaj do koszyka")
    expect(page).to have_text("Pełny program nie jest jeszcze dostępny do zakupu")
  end

  it "keeps the account route for a purchased program when new sales are paused" do
    product = create_product(kind: :audio_process)
    user = User.create!(email: "listener@example.com", password: "password123")
    user.orders.create!(status: :paid, order_items: [ OrderItem.new(product: product) ])
    product.update!(expected_chapter_count: nil)
    sign_in user

    get audio_process_path

    page = Capybara.string(response.body)
    expect(page).to have_link(href: dashboard_index_path(anchor: "product_#{product.id}"))
    expect(page).not_to have_button("Dodaj do koszyka")
  end

  it "formats existing markdown in the includes list" do
    create_product(kind: :audio_process, includes: [ "Wstęp do procesu", "**Program**", "- **Siedem** nagrań", "- Plan działania" ])

    get audio_process_path

    page = Capybara.string(response.body)
    expect(page).to have_css(".trix-content p", text: "Wstęp do procesu")
    expect(page).to have_css("details .trix-content li strong", text: "Siedem", visible: :all)
    expect(page).to have_css("details .trix-content li", text: "Plan działania", visible: :all)
    expect(response.body).not_to include("**Siedem**")
  end

  it "shows a truthful empty state when no audio process is published" do
    get audio_process_path

    expect(response.body).to include("Audioproces pojawi się tutaj wkrótce")
  end
end
