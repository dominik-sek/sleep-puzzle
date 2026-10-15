require "rails_helper"

RSpec.describe "Typed product URLs", type: :request do
  before do
    allow(PaddlePriceCatalogService).to receive(:call).and_return([])
  end

  [ nil, :en ].each do |locale|
    prefix = locale ? "/en" : ""

    it "keeps the catalogue and links directly to typed slug pages in #{locale || :pl}" do
      program = create_product(name: "Spokojny sen", kind: :audio_process)
      story = create_product(name: "Sen sowy")

      expect(audio_process_path(slug: program.slug, locale: locale)).to eq("#{prefix}/audioprocesses/spokojny-sen")
      expect(story_path(slug: story.slug, locale: locale)).to eq("#{prefix}/stories/sen-sowy")
      get products_path(locale: locale)
      page = Capybara.string(response.body)
      expect(page).to have_link(program.name, href: "#{prefix}/audioprocesses/spokojny-sen")
      expect(page).to have_link(story.name, href: "#{prefix}/stories/sen-sowy")

      [ program, story ].each do |product|
        get catalogue_product_path(product, locale: locale), params: { source: "catalogue" }
        expect(response).to have_http_status(:ok)
        alternate = catalogue_product_path(product, locale: locale ? nil : :en, source: "catalogue")
        expect(Capybara.string(response.body)).to have_link(href: alternate)
      end
    end

    it "rejects wrong-kind slugs, unknown slugs, drafts, and numeric ID lookups in #{locale || :pl}" do
      program = create_product(kind: :audio_process)
      story = create_product
      draft = create_product(published: false)
      [ "#{prefix}/stories/#{program.slug}", "#{prefix}/audioprocesses/#{story.slug}",
        "#{prefix}/stories/missing", "#{prefix}/audioprocesses/missing",
        "#{prefix}/stories/#{draft.slug}", "#{prefix}/stories/#{story.id}",
        "#{prefix}/audioprocesses/#{program.id}" ].each do |path|
        get path
        expect(response).to have_http_status(:not_found), path
      end
    end

    it "removes legacy detail and media URLs without redirects in #{locale || :pl}" do
      product = create_product
      [ "", "/preview", "/stream", "/trailer", "/chapters/1/stream" ].each do |suffix|
        get "#{prefix}/products/#{product.id}#{suffix}"
        expect(response).to have_http_status(:not_found)
      end
    end

    it "serves only the matching type's public media in #{locale || :pl}" do
      story = create_product(preview_cdn_path: "/stories/preview.mp3")
      program = create_product(kind: :audio_process, trailer_cdn_path: "/programs/trailer.mp4")
      with_bunny_cdn

      get preview_story_path(slug: story.slug, locale: locale)
      expect(response).to have_http_status(:redirect)
      get trailer_audio_process_path(slug: program.slug, locale: locale)
      expect(response).to have_http_status(:redirect)
      get preview_story_path(slug: program.slug, locale: locale)
      expect(response).to have_http_status(:not_found)
      get trailer_audio_process_path(slug: story.slug, locale: locale)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "keeps numeric IDs in admin routes and cart operations" do
    product = create_product
    expect(edit_admin_product_path(product)).to eq("/admin/products/#{product.id}/edit")
    post cart_items_path, params: { product_id: product.id }
    get cart_path
    page = Capybara.string(response.body)
    expect(page).to have_link(product.name, href: story_path(slug: product.slug))
    expect(page).to have_css("form[action='#{cart_item_path(product_id: product.id)}']")
  end
end
