require "rails_helper"

RSpec.describe "Catalogue purchase states", type: :request do
  before do
    with_bunny_cdn
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456") ])
  end

  def ownership_queries
    queries = []
    listener = lambda do |*args|
      payload = args.last
      next if payload[:cached] || payload[:name] == "SCHEMA"

      sql = payload[:sql]
      queries << sql if sql.start_with?("SELECT") && sql.include?('"order_items"')
    end
    ActiveSupport::Notifications.subscribed(listener, "sql.active_record") { yield }
    queries
  end

  def order_for(user, product, status: :paid, refunded: false)
    user.orders.create!(status: status, order_items: [
      OrderItem.new(product: product, refunded_at: refunded ? Time.current : nil)
    ])
  end

  [ :shop, :programs, :stories ].each do |surface|
    it "uses two ownership queries for one or ten products on #{surface}" do
      user = User.create!(email: "buyer@example.com", password: "password123")
      sign_in user
      path = { shop: products_path, programs: audio_processes_path, stories: stories_path }.fetch(surface)

      [ 1, 10 ].each do |count|
        (count - Product.count).times do |i|
          kind = surface == :programs || (surface == :shop && i.odd?) ? :audio_process : :bedtime_story
          create_product(kind: kind, name: "Recording #{count}-#{i}", preview_cdn_path: "/previews/sample.wav")
        end

        queries = ownership_queries { get path }

        expect(response).to have_http_status(:ok)
        expect(Capybara.string(response.body)).to have_css("main article", count: count)
        expect(queries.size).to eq(2), "#{surface} with #{count} products made #{queries.size} ownership queries"
      end
    end
  end

  it "does not query ownership for signed-out or empty collections" do
    paths = [ products_path, audio_processes_path, stories_path ]
    sign_in User.create!(email: "buyer@example.com", password: "password123")
    paths.each { |path| expect(ownership_queries { get path }).to be_empty }
    sign_out :user
    create_product(preview_cdn_path: "/previews/sample.wav")
    create_product(kind: :audio_process)
    paths.each { |path| expect(ownership_queries { get path }).to be_empty }
  end

  %i[audio_process bedtime_story].each do |kind|
    it "preserves paid, pending, refunded and other-user access rules for #{kind}" do
      user = User.create!(email: "buyer@example.com", password: "password123")
      other = User.create!(email: "other@example.com", password: "password123")
      products = %i[paid pending refunded canceled failed other_user purchased_again paid_and_pending].index_with do |state|
        create_product(kind: kind, name: "#{kind} #{state}", preview_cdn_path: "/previews/sample.wav")
      end
      order_for(user, products[:paid])
      order_for(user, products[:pending], status: :pending)
      order_for(user, products[:refunded], refunded: true)
      order_for(user, products[:canceled], status: :canceled)
      order_for(user, products[:failed], status: :payment_failed)
      order_for(other, products[:other_user])
      order_for(user, products[:purchased_again], refunded: true)
      order_for(user, products[:purchased_again])
      order_for(user, products[:paid_and_pending])
      order_for(user, products[:paid_and_pending], status: :pending)
      sign_in user

      path = kind == :audio_process ? audio_processes_path : stories_path
      get path

      page = Capybara.string(response.body)
      products.each do |state, product|
        card = page.find("main h2 a[href='#{catalogue_product_path(product)}']").find(:xpath, "ancestor::article")
        case state
        when :paid, :purchased_again
          expect(card).to have_link("Posłuchaj w koncie", href: dashboard_index_path(anchor: "product_#{product.id}"))
          expect(card).not_to have_button("Dodaj do koszyka")
        when :pending, :paid_and_pending
          expect(card).to have_link("Płatność w trakcie", href: dashboard_index_path(anchor: "product_#{product.id}"))
          expect(card).not_to have_button("Dodaj do koszyka")
        else
          expect(card).to have_button("Dodaj do koszyka")
        end
        next unless kind == :bedtime_story

        if %i[paid purchased_again paid_and_pending].include?(state)
          expect(card).not_to have_css("audio")
        else
          expect(card).to have_css("audio[preload='none']")
        end
      end
    end
  end

  it "refreshes catalogue and cart states across payment and refund changes" do
    user = User.create!(email: "buyer@example.com", password: "password123")
    story = create_product(preview_cdn_path: "/previews/sample.wav")
    sign_in user
    get stories_path
    expect(Capybara.string(response.body)).to have_button("Dodaj do koszyka")

    paid = order_for(user, story)
    get stories_path
    expect(Capybara.string(response.body)).to have_link("Posłuchaj w koncie")
    expect(Capybara.string(response.body)).not_to have_css("main audio")
    post cart_items_path, params: { product_id: story.id }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(Cart.from_session(session, owner: user)).to be_empty

    paid.order_items.first.update!(refunded_at: Time.current)
    get stories_path
    expect(Capybara.string(response.body)).to have_button("Dodaj do koszyka")
    expect(Capybara.string(response.body)).to have_css("main audio")
    post cart_items_path, params: { product_id: story.id }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(response.body).to include("Usuń z koszyka")
    expect(Cart.from_session(session, owner: user)).to include(story)

    pending = order_for(user, story, status: :pending)
    get stories_path
    expect(Capybara.string(response.body)).to have_link("Płatność w trakcie")
    post cart_items_path, params: { product_id: story.id }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(Cart.from_session(session, owner: user).buyable).to be_empty
    expect(response.body).to include("Płatność w trakcie")

    pending.update!(status: :canceled)
    delete cart_item_path(product_id: story.id), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(response.body).to include("Dodaj do koszyka")
    get stories_path
    expect(Capybara.string(response.body)).to have_button("Dodaj do koszyka")
  end
end
