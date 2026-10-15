require "rails_helper"

RSpec.describe "Product slug redirects", type: :request do
  before { allow(PaddlePriceCatalogService).to receive(:call).and_return([]) }

  def regenerate(product, name)
    product.assign_translation(:name, :pl, name)
    product.regenerate_slug = true
    product.slug_preview = product.suggested_slug
    product.save!
  end

  [ nil, :en ].each do |locale|
    %i[audio_process bedtime_story].each do |kind|
      it "redirects every earlier #{kind} slug directly to the latest URL in #{locale || :pl}" do
        product = create_product(kind: kind, name: "Pierwszy")
        first = catalogue_product_path(product, locale: locale, source: "shared")
        regenerate(product, "Drugi")
        second = catalogue_product_path(product, locale: locale, source: "shared")
        regenerate(product, "Trzeci")
        [ first, second ].each do |path|
          get path
          expect(response).to have_http_status(:moved_permanently)
          expect(response).to redirect_to(catalogue_product_path(product, locale: locale, source: "shared"))
          follow_redirect!
          expect(response).to have_http_status(:ok)
        end
        wrong_kind = kind == :audio_process ? story_path(slug: "pierwszy", locale: locale) : audio_process_path(slug: "pierwszy", locale: locale)
        get wrong_kind
        expect(response).to have_http_status(:not_found)
        product.update!(published: false)
        get first
        expect(response).to have_http_status(:not_found)
      end
    end

    it "preserves public sample and trailer routes in #{locale || :pl}" do
      with_bunny_cdn
      story = create_product(name: "Sowa", preview_cdn_path: "/previews/owl.mp3")
      program = create_product(kind: :audio_process, name: "Sen", trailer_cdn_path: "/programs/trailer.mp4")
      previous_preview = preview_story_path(slug: story.slug, locale: locale)
      previous_trailer = trailer_audio_process_path(slug: program.slug, locale: locale)
      regenerate(story, "Nowa sowa")
      regenerate(program, "Nowy sen")
      [ [ previous_preview, preview_story_path(slug: story.slug, locale: locale) ],
        [ previous_trailer, trailer_audio_process_path(slug: program.slug, locale: locale) ] ].each do |previous, current|
        get previous
        expect(response).to have_http_status(:moved_permanently)
        expect(response).to redirect_to(current)
        follow_redirect!
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("token=")
      end
    end
  end

  it "authenticates old stream URLs and checks ownership after redirecting" do
    story = create_product(name: "Sowa")
    path = stream_story_path(slug: story.slug)
    regenerate(story, "Nowa sowa")
    get path
    expect(response).to redirect_to(new_user_session_path)
    sign_in User.create!(email: "listener@example.com", password: "password123")
    expect(BunnySignedUrlService).not_to receive(:call)
    get path
    expect(response).to have_http_status(:moved_permanently)
    follow_redirect!
    expect(response).to have_http_status(:forbidden)
  end

  it "keeps purchased unpublished chapters playable and preserves order item and chapter IDs" do
    with_bunny_cdn
    program = create_product(kind: :audio_process, name: "Sen")
    buyer = User.create!(email: "buyer@example.com", password: "password123")
    order = buyer.orders.create!(status: :paid, order_items: [ OrderItem.new(product: program) ])
    item = order.order_items.sole
    chapter = program.audio_chapters.sole
    previous = stream_chapter_audio_process_path(slug: program.slug, chapter_id: chapter.id, order_item_id: item.id, locale: :en)
    regenerate(program, "Nowy sen")
    program.update!(published: false)
    sign_in buyer
    get previous
    expect(response).to have_http_status(:moved_permanently)
    expect(response).to redirect_to(stream_chapter_audio_process_path(slug: program.slug, chapter_id: chapter.id, order_item_id: item.id, locale: :en))
    follow_redirect!
    expect(response).to have_http_status(:redirect)
    expect(response.location).to include("token=")
    item.update!(refunded_at: Time.current)
    get previous
    follow_redirect!
    expect(response).to have_http_status(:forbidden)
  end
end
