require 'rails_helper'

RSpec.describe "About", type: :request do
  describe "GET /about" do
    it "renders the CMS copy from its declared defaults on an empty database" do
      expect(ContentBlock.count).to eq(0)

      get about_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Karola")
      expect(response.body).to include("Konsultantka snu dziecięcego")
      expect(response.body).to include("układa sen rodzin jak puzzle")
      expect(response.body).not_to include("brak treści")
    end

    it "renders the pull quote and the copy on both sides of it" do
      get about_path

      expect(response.body).to include("Piasek jest fajny")
      expect(response.body).to include("zdrowy sen zaczyna się od empatii")
      expect(response.body).to include("gadającą encyklopedię")
    end

    it "lists the certifications from the collection's defaults" do
      get about_path

      expect(response.body).to include("OCN Level 6")
      expect(response.body).to include("Child Care Development")
      expect(response.body).to include("CBTi")
    end

    it "points its call to action at the booking form" do
      get about_path

      expect(response.body).to include("Umów konsultację")
      expect(response.body).to include(bookings_path)
    end

    # nothing uploaded yet is the normal state on a fresh deploy, and an empty
    # frame beats a broken <img>
    it "leaves an empty frame where the photo will go" do
      get about_path

      expect(response.body).to include("border-dashed")
    end

    it "renders the uploaded photo once there is one" do
      ContentBlock.sync!
      block = ContentBlock.find_by!(key: "about.intro.photo")
      block.image.attach(io: Rails.root.join("spec/fixtures/files/photo.png").open, filename: "photo.png")

      get about_path

      expect(response.body).not_to include("border-dashed")
    end

    it "renders the English copy under the English locale" do
      I18n.with_locale(:en) { get about_path }

      expect(response.body).to include("Children&#39;s Sleep Consultant")
      expect(response.body).to include("Certifications &amp; qualifications")
      expect(response.body).to include("Book a consultation")
    end

    it "does not require signing in" do
      get about_path

      expect(response).to have_http_status(:ok)
    end
  end

  it "is reachable from the navbar, which used to be a dead link" do
    get root_path

    expect(response.body).to include(%(href="#{about_path}"))
  end
end
