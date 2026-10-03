require 'rails_helper'

RSpec.describe "Shared testimonials", type: :request do
  before do
    allow(GoogleCalendarService).to receive(:call).and_return(instance_double(GoogleCalendarService, busy: []))
  end

  def add_testimonial(position:, quote:, author: "Rodzic", effect: nil, en_quote: nil, en_author: nil)
    item = ContentItem.new(collection_key: "testimonials.entries", position: position)
    item.assign_value("quote", :pl, quote)
    item.assign_value("author", :pl, author)
    item.assign_value("effect", :pl, effect) if effect
    item.assign_value("quote", :en, en_quote) if en_quote
    item.assign_value("author", :en, en_author) if en_author
    item.save!
    item
  end

  it "hides the section on all three pages until an opinion has a quote and signature" do
    item = ContentItem.create!(collection_key: "testimonials.entries", position: 1)
    item.assign_value("quote", :pl, "Bez podpisu")
    item.save!

    [ root_path, packages_path, audio_process_path ].each do |path|
      get path
      expect(response.body).not_to include('id="testimonials-title"', "Bez podpisu")
    end
  end

  it "renders one Rails Blocks card with the same opinion on all three pages" do
    add_testimonial(position: 1, quote: "Wreszcie mamy spokojne wieczory", effect: "Łatwiejsze zasypianie")

    [ root_path, audio_process_path, packages_path ].each do |path|
      get path

      page = Capybara.string(response.body)
      expect(page).to have_css('section[aria-labelledby="testimonials-title"] [data-controller="carousel"] blockquote', count: 1)
      expect(response.body).to include("Wreszcie mamy spokojne wieczory", "Łatwiejsze zasypianie", "Opinie")
      expect(page).to have_no_css('section[aria-labelledby="testimonials-title"] img')
    end
  end

  it "uses a carousel with one mobile card and at most three desktop cards, in admin order" do
    add_testimonial(position: 2, quote: "Druga opinia")
    add_testimonial(position: 1, quote: "Pierwsza opinia")

    get root_path
    page = Capybara.string(response.body)
    expect(page).to have_css('section[aria-labelledby="testimonials-title"] [data-carousel-target="viewport"] blockquote', count: 2)
    expect(response.body).to include("basis-full", "lg:basis-[calc((100%-2rem)/3)]")
    expect(response.body.index("Pierwsza opinia")).to be < response.body.index("Druga opinia")

    add_testimonial(position: 3, quote: "Trzecia opinia")
    add_testimonial(position: 4, quote: "Czwarta opinia")
    get root_path
    page = Capybara.string(response.body)
    expect(page).to have_css('section[aria-labelledby="testimonials-title"] [data-carousel-target="viewport"] blockquote', count: 4)
  end

  it "places opinions after the approach on home and before the calendar on packages" do
    add_testimonial(position: 1, quote: "Pomoc Karoli")

    get root_path
    expect(response.body.index('id="help-title"')).to be < response.body.index('id="testimonials-title"')

    get packages_path
    expect(response.body.index('id="testimonials-title"')).to be < response.body.index('id="calendar"')
  end

  it "renders English translations and falls back to Polish for untranslated opinions" do
    add_testimonial(position: 1, quote: "Polski cytat", en_quote: "English quote", en_author: "Parent")
    add_testimonial(position: 2, quote: "Tylko po polsku")

    get root_path(locale: :en)
    expect(response.body).to include("Testimonials", "English quote", "Parent", "Tylko po polsku")
    expect(response.body).not_to include("Polski cytat")
  end

  it "lets the admin add, translate, and reorder opinions through the existing CMS" do
    admin = User.create!(email: "owner@example.com", password: "password123", admin: true)
    sign_in admin

    2.times { post admin_content_items_path, params: { collection_key: "testimonials.entries" } }
    first, second = ContentItem.for_collection("testimonials.entries").to_a

    get admin_content_blocks_path(open: "testimonials.entries")
    expect(response.body).to include("items[#{first.id}][values][quote][pl]", "items[#{first.id}][values][quote][en]")

    patch admin_content_blocks_path, params: {
      section: "testimonials.entries",
      items: {
        first.id.to_s => { position: "2", values: { quote: { pl: "Pierwsza", en: "First" }, author: { pl: "Rodzic" } } },
        second.id.to_s => { position: "1", values: { quote: { pl: "Druga" }, author: { pl: "Mama" } } }
      }
    }

    expect(response).to redirect_to(admin_content_blocks_path(open: "testimonials.entries"))
    expect(first.reload.value_for("quote", :en)).to eq("First")

    get root_path
    expect(response.body.index("Druga")).to be < response.body.index("Pierwsza")
  end
end
