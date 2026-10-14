require "rails_helper"

RSpec.describe "Canonical catalogue and testimonial routes", type: :request do
  [ nil, :en ].each do |locale|
    prefix = locale ? "/en" : ""

    it "uses English collection URLs and no Polish route aliases in #{locale || :pl}" do
      expect(audio_process_path(locale: locale)).to eq("#{prefix}/audio-processes")
      expect(stories_path(locale: locale)).to eq("#{prefix}/stories")
      %w[audioproces audioprocesy bajki].each do |segment|
        expect { Rails.application.routes.recognize_path("#{prefix}/#{segment}") }
          .to raise_error(ActionController::RoutingError)
      end
      %i[get patch put].each do |method|
        expect { Rails.application.routes.recognize_path("#{prefix}/opinia/token", method: method) }
          .to raise_error(ActionController::RoutingError)
      end
    end

    it "uses only the canonical testimonial form and success URL in #{locale || :pl}" do
      invitation = TestimonialInvitation.create!(recipient_label: "Klientka")
      path = testimonial_invitation_path(invitation.token, locale: locale)
      expect(path).to eq("#{prefix}/testimonials/#{invitation.token}")
      get path
      expect(Capybara.string(response.body)).to have_css("form[action='#{path}']")

      patch path, params: { testimonial_invitation: { quote: "Pomocna rozmowa", author: "Mama", publication_consent: "0" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(Capybara.string(response.body)).to have_css("form[action='#{path}']")

      put path, params: { testimonial_invitation: { quote: "Pomocna rozmowa", author: "Mama", publication_consent: "1" } }
      expect(response).to redirect_to(path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(invitation.reload).to be_submitted
    end
  end
end
