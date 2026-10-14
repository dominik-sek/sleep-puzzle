require "rails_helper"

RSpec.describe "Stories collection", type: :request do
  before do
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456") ])
  end

  [ nil, :en ].each do |locale|
    it "lists every published story in order with the same product URLs in #{locale || :pl}" do
      later = create_product(name: "Druga", name_en: "Second", position: 2, length_minutes: 12)
      first = create_product(name: "Pierwsza", name_en: "First", position: 1)
      create_product(name: "Nieopublikowana", published: false)
      create_product(name: "Bez nagrania").update_column(:cdn_path, nil)
      create_product(name: "Program", kind: :audio_process)

      get stories_path(locale: locale)

      expect(response).to have_http_status(:ok)
      page = Capybara.string(response.body)
      expect(page).to have_css("main h1", text: locale ? "Audio stories" : "Bajki audio", count: 1)
      expect(page.all("main article h2 a").map { |link| link[:href] }).to eq([ first, later ].map { |p| product_path(p, locale: locale) })
      expect(page.find("main")).not_to have_text("Program")
      expect(page.find("main")).not_to have_text("Nieopublikowana")
      expect(page.find("main")).not_to have_text("Bez nagrania")
      expect(page.all("main article").first).not_to have_text(locale ? "Length" : "Długość")
      expect(page.all("main article").last).to have_text("12 min")
      expect(page).to have_link(href: stories_path(locale: locale ? nil : :en))
      expect(page).to have_link(href: products_path(locale: locale))
    end

    it "renders editable collection copy, empty state and Polish fallback in #{locale || :pl}" do
      ContentBlock.create!(key: "stories.hero.title", value_pl: "Moje bajki")
      ContentBlock.create!(key: "stories.hero.intro", value_pl: "Posłuchaj ze mną.")
      ContentBlock.create!(key: "stories.hero.empty", value_pl: "Nie ma teraz dostępnych nagrań.")

      get stories_path(locale: locale)

      page = Capybara.string(response.body)
      expect(page).to have_css("title", text: "Moje bajki", visible: :all)
      expect(page).to have_css("h1", text: "Moje bajki")
      expect(page).to have_text("Posłuchaj ze mną.")
      expect(page).to have_text("Nie ma teraz dostępnych nagrań.")
      expect(page).not_to have_css("article, main audio, main form")
      expect(page).to have_link(href: products_path(locale: locale))
    end
  end

  [ 1, 2, 5 ].each do |count|
    it "renders all #{count} stories with the established small-collection caps" do
      count.times { |i| create_product(name: "Bajka #{i}") }
      get stories_path

      page = Capybara.string(response.body)
      expect(page).to have_css("main article", count: count)
      cap = { 1 => 320, 2 => 664 }[count]
      if cap
        expect(page).to have_css("main div[class*='sm:max-w-[#{cap}px]']")
      else
        expect(page).not_to have_css("main div[class*='sm:max-w-']")
      end
    end
  end

  it "offers labelled deferred samples only on the stories collection and detail pages" do
    with_bunny_cdn
    story = create_product(preview_cdn_path: "/previews/story.mp3")
    create_product(name: "Bez próbki")
    [ stories_path, product_path(story) ].each do |path|
      get path
      page = Capybara.string(response.body)
      expect(page).to have_css("audio[controls][preload='none'][src='#{preview_product_path(story)}']", count: 1)
      expect(page.find("audio")[:"aria-label"]).to include(story.name)
      expect(page).not_to have_css("[id^='cart_'] audio")
    end
    [ products_path, audio_process_path ].each do |path|
      get path
      expect(Capybara.string(response.body)).not_to have_css("main audio")
    end
  end

  it "omits a sample when CDN playback is unconfigured" do
    create_product(preview_cdn_path: "/previews/story.mp3")
    get stories_path
    expect(Capybara.string(response.body)).not_to have_css("main audio")
  end

  it "updates only the commerce region when a story is added or removed" do
    story = create_product
    [ :post, :delete ].each do |verb|
      path = verb == :post ? cart_items_path : cart_item_path(product_id: story.id)
      public_send(verb, path, params: { product_id: story.id }, headers: { "Accept" => "text/vnd.turbo-stream.html" })
      page = Capybara.string(response.body)
      expect(page).to have_css("turbo-stream[target='cart_toggle_product_#{story.id}']", visible: :all)
      expect(page).not_to have_css("audio", visible: :all)
      expect(response.body).to include(verb == :post ? "Usuń z koszyka" : "Dodaj do koszyka")
    end
  end

  [ :stories, :shop, :detail ].each do |surface|
    %i[available unavailable in_cart owned pending].each do |state|
      it "shows truthful #{state} commerce on #{surface}" do
        with_bunny_cdn
        story = create_product(preview_cdn_path: "/previews/story.mp3")
        post cart_items_path, params: { product_id: story.id } if state == :in_cart
        if %i[owned pending].include?(state)
          user = User.create!(email: "buyer@example.com", password: "password123")
          order = user.orders.create!(status: :pending, order_items: [ OrderItem.new(product: story) ])
          order.mark_paid!(transaction_id: "txn_#{order.id}") if state == :owned
          sign_in user
        end
        allow(PaddlePriceCatalogService).to receive(:call).and_return([]) if %i[unavailable owned pending].include?(state)
        path = { stories: stories_path, shop: products_path, detail: product_path(story) }.fetch(surface)

        get path

        page = Capybara.string(response.body).find("main")
        case state
        when :available
          expect(page).to have_css("button[aria-label='Dodaj do koszyka - #{story.name}']")
        when :unavailable
          expect(page).to have_text("Chwilowo niedostępne")
          expect(page).to have_link("Zapytaj o to nagranie")
          expect(page).not_to have_css("button[aria-label='Dodaj do koszyka - #{story.name}']")
        when :in_cart
          expect(page).to have_css("button[aria-label='Usuń z koszyka - #{story.name}']")
          expect(page).to have_text("Dodano")
        when :owned, :pending
          label = state == :owned ? "Posłuchaj w koncie" : "Płatność w trakcie"
          expect(page).to have_link(label, href: dashboard_index_path(anchor: "product_#{story.id}"))
          expect(page).not_to have_css("button[aria-label='Dodaj do koszyka - #{story.name}']")
          expect(page).not_to have_css("audio") if state == :owned
        end
      end
    end
  end
end
