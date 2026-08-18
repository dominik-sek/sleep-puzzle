require 'rails_helper'

RSpec.describe "Newsletter subscriptions", type: :request do
  def valid_params
    { newsletter_signup: { email: "rodzic@example.com" } }
  end

  # The controller's job is to decide what the visitor sees; whether Brevo took
  # the address is the service's, and it has its own spec.
  def stub_brevo(subscribed:)
    service = instance_double(BrevoSubscriptionService, subscribed?: subscribed)
    allow(BrevoSubscriptionService).to receive(:call).and_return(service)
    service
  end

  describe "the form on the home page" do
    it "renders inside its own frame, from the CMS defaults" do
      get root_path

      expect(response.body).to include("Newsletter Sleep Puzzle")
      expect(response.body).to include("Raz na jakiś czas")
      expect(response.body).to include("newsletter_form")
      expect(response.body).to include(%(name="newsletter_signup[email]"))
    end

    it "is translated on the English home page" do
      get root_path(locale: :en)

      expect(response.body).to include("Sleep Puzzle newsletter")
      expect(response.body).to include("Subscribe")
    end
  end

  describe "POST /newsletter_subscription" do
    it "hands the address to Brevo and swaps in the thank-you state" do
      stub_brevo(subscribed: true)

      post newsletter_subscription_path, params: valid_params

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sprawdź skrzynkę")
      expect(response.body).not_to include(%(name="newsletter_signup[email]"))
    end

    # the address is not on the list until Brevo's mail is answered, so the
    # confirmation has to send them to their inbox rather than claim it is done
    it "tells them to confirm rather than saying they are subscribed" do
      stub_brevo(subscribed: true)

      post newsletter_subscription_path, params: valid_params

      expect(response.body).to include("potwierdzić zapis")
    end

    it "passes the address and a return address into the service" do
      stub_brevo(subscribed: true)

      post newsletter_subscription_path, params: valid_params

      expect(BrevoSubscriptionService).to have_received(:call)
        .with(hash_including(email: "rodzic@example.com"))
    end

    # Brevo sends them back to the site once they confirm, and it should be the
    # site in the language they signed up in
    it "sends an English signup back to the English home page" do
      stub_brevo(subscribed: true)

      post newsletter_subscription_path(locale: :en), params: valid_params

      expect(BrevoSubscriptionService).to have_received(:call)
        .with(hash_including(redirect_url: a_string_including("/en")))
    end

    context "when the address is not usable" do
      it "comes back into the frame with the form rather than a bare error" do
        post newsletter_subscription_path, params: { newsletter_signup: { email: "not-an-address" } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("newsletter_form")
        expect(response.body).to include(%(name="newsletter_signup[email]"))
      end

      it "never reaches Brevo" do
        expect(BrevoSubscriptionService).not_to receive(:call)

        post newsletter_subscription_path, params: { newsletter_signup: { email: "" } }
      end

      # a POST with nothing in it is a form someone submitted empty, not a 400
      it "handles a submission with no parameters at all" do
        post newsletter_subscription_path

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include(%(name="newsletter_signup[email]"))
      end
    end

    context "when Brevo refuses" do
      it "says so on the form instead of showing a thank-you" do
        stub_brevo(subscribed: false)

        post newsletter_subscription_path, params: valid_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Nie udało się zapisać")
        expect(response.body).to include(%(name="newsletter_signup[email]"))
      end
    end
  end
end
