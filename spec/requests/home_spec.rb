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

  it "shows FAQ entries between the methodology and contact, using the accordion" do
    first = ContentItem.create!(collection_key: "home.faq", position: 1)
    first.assign_value("question", :pl, "Jak wygląda współpraca?")
    first.assign_value("answer", :pl, "Najpierw rozmawiamy.\nPotem układamy plan.")
    first.assign_value("question", :en, "How does it work?")
    first.assign_value("answer", :en, "First we talk.")
    first.save!

    second = ContentItem.create!(collection_key: "home.faq", position: 2)
    second.assign_value("question", :pl, "Czy mogę pracować we własnym tempie?")
    second.assign_value("answer", :pl, "Tak, możesz.")
    second.save!

    get root_path

    page = Nokogiri::HTML(response.body)
    faq = page.at_css('section[aria-labelledby="faq-title"]')
    expect(faq).to be_present
    expect(faq.css('[data-controller="accordion"] [data-accordion-target="trigger"]').map { |button| button.text.strip })
      .to eq([ "Jak wygląda współpraca?", "Czy mogę pracować we własnym tempie?" ])
    expect(faq.text).to include("Najpierw rozmawiamy.", "Potem układamy plan.")
    expect(faq.css('[data-accordion-target="content"]').size).to eq(2)
    expect(response.body.index("Moja metodologia")).to be < response.body.index('id="faq-title"')
    expect(response.body.index('id="faq-title"')).to be < response.body.index("Napisz na Instagramie")

    get root_path(locale: :en)

    expect(response.body).to include("Frequently asked questions", "How does it work?", "First we talk.")
  end

  it "hides FAQ until a complete question and answer are saved" do
    item = ContentItem.create!(collection_key: "home.faq", position: 1)
    item.assign_value("question", :pl, "Pytanie bez odpowiedzi?")
    item.save!

    get root_path

    expect(response.body).not_to include('id="faq-title"', "Pytanie bez odpowiedzi?")
  end

  it "alternates section backgrounds for every combination of optional sections" do
    backgrounds = lambda do
      get root_path
      Nokogiri::HTML(response.body).css("main > div > section").map do |section|
        section["class"].split.find { |class_name| class_name.in?(%w[bg-ink bg-ink-soft]) }
      end
    end

    expect(backgrounds.call).to eq(%w[bg-ink bg-ink-soft bg-ink bg-ink-soft])

    faq = ContentItem.create!(collection_key: "home.faq", position: 1)
    faq.assign_value("question", :pl, "Pytanie?")
    faq.assign_value("answer", :pl, "Odpowiedź.")
    faq.save!
    expect(backgrounds.call).to eq(%w[bg-ink bg-ink-soft bg-ink bg-ink-soft bg-ink])

    testimonial = ContentItem.create!(collection_key: "testimonials.entries", position: 1)
    testimonial.assign_value("quote", :pl, "Dobrze śpimy")
    testimonial.assign_value("author", :pl, "Mama")
    testimonial.save!
    expect(backgrounds.call).to eq(%w[bg-ink bg-ink-soft bg-ink bg-ink-soft bg-ink bg-ink-soft])

    faq.destroy!
    expect(backgrounds.call).to eq(%w[bg-ink bg-ink-soft bg-ink bg-ink-soft bg-ink])
  end

  it "renders the English offer choices" do
    get root_path(locale: :en)

    expect(response.body).to include("How can I help you?", "Audio process", "Work together 1:1")
  end
end
