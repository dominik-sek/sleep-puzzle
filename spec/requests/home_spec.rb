require 'rails_helper'

RSpec.describe "Home", type: :request do
  it "shows the two offer paths and hides the old catalogue and newsletter sections" do
    create_package(name: "Szybka ulga")
    create_product(name: "Bajka o sowie", kind: :bedtime_story)

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Jak mogę Ci pomóc", audio_process_path, packages_path)
    expect(response.body).not_to include("Szybka ulga", "Bajka o sowie", "Newsletter Sleep Puzzle")
    expect(response.body).not_to include(%(href="#{contact_path}"))
  end

  it "uses editable hero copy and the uploaded portrait" do
    ContentBlock.sync!
    ContentBlock.find_by!(key: "home.hero.title").update!(value_pl: "Nowy tytuł")
    ContentBlock.find_by!(key: "home.about.photo")
                .image.attach(io: file_fixture("photo.png").open, filename: "photo.png", content_type: "image/png")

    get root_path

    expect(response.body).to include("Nowy tytuł", 'alt="Karola"')
  end

  it "has no testimonial section before real material is entered" do
    get root_path

    expect(response.body).not_to include('id="testimonials-title"')
  end

  it "shares only complete testimonials" do
    blank = ContentItem.create!(collection_key: "testimonials.entries", position: 1)
    complete = ContentItem.create!(collection_key: "testimonials.entries", position: 2)
    complete.assign_value("quote", :pl, "Śpimy spokojniej")
    complete.assign_value("author", :pl, "Mama dziecka")
    complete.save!

    get root_path

    expect(response.body).to include("Śpimy spokojniej", "Mama dziecka")
    expect(response.body.scan('id="testimonials-title"').size).to eq(1)
  end

  it "renders the English offer choices" do
    get root_path(locale: :en)

    expect(response.body).to include("How can I help you?", "Audio process", "Work together 1:1")
  end
end
