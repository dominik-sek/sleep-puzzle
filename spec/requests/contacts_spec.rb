require 'rails_helper'

RSpec.describe "Contacts", type: :request do
  include ActiveJob::TestHelper

  # pinned rather than read from the environment, so the suite asserts the same
  # thing on a machine whose .env has no owner address
  let(:owner_email) { "karola@example.com" }

  before { stub_const("ENV", ENV.to_h.merge("OWNER_EMAIL" => owner_email)) }

  def valid_params
    { contact_message: { name: "Jan Kowalski", email: "jan@example.com", body: "Córka budzi się co godzinę." } }
  end

  describe "GET /contact" do
    it "renders the CMS copy from its declared defaults on an empty database" do
      expect(ContentBlock.count).to eq(0)

      get contact_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Masz pytanie zanim się umówisz?")
      expect(response.body).to include("Wyślij wiadomość")
      expect(response.body).not_to include("brak treści")
    end

    it "renders the link tiles from the collection's defaults" do
      get contact_path

      expect(response.body).to include("Instagram @sleep.puzzle")
      expect(response.body).to include("https://www.instagram.com/sleep.puzzle")
      expect(response.body).to include("Regulamin współpracy")
    end

    it "gives each tile the emoji the design puts in front of its name" do
      get contact_path

      instagram = response.body[/<a[^>]*instagram\.com[^>]*>.*?<\/a>/m]
      # decoration, so it is announced to nobody
      expect(instagram).to include(%(<span aria-hidden="true">📷</span>))
    end

    it "opens an external tile in a new tab and leaves an internal one in place" do
      get contact_path

      instagram = response.body[/<a[^>]*instagram\.com[^>]*>.*?<\/a>/m]
      expect(instagram).to include('target="_blank"', 'rel="noopener"')

      unset = response.body[/<a[^>]*href="#"[^>]*>.*?<\/a>/m]
      expect(unset).not_to include("target=")
    end

    it "sends a link the owner has not pointed anywhere to a safe target" do
      ContentItem.sync!
      link = ContentItem.for_collection("contact.links").first
      link.assign_value("url", :pl, "javascript:alert(1)")
      link.save!

      get contact_path

      expect(response.body).not_to include("javascript:alert")
    end

    it "renders the English copy under the English locale" do
      I18n.with_locale(:en) { get contact_path }

      expect(response.body).to include("Got a question before booking?", "Send message")
    end

    it "does not require signing in" do
      get contact_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /contact" do
    it "mails the owner and confirms in place" do
      expect {
        post contact_path, params: valid_params
      }.to have_enqueued_mail(ContactMailer, :new_message)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dziękuję za wiadomość!")
    end

    it "sends to the owner with the sender as reply-to, so answering reaches them" do
      perform_enqueued_jobs do
        post contact_path, params: valid_params
      end

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ owner_email ])
      expect(mail.reply_to).to eq([ "jan@example.com" ])
      expect(mail.subject).to include("Jan Kowalski")
      # decoded, not encoded: the parts ship as quoted-printable, so Polish
      # characters never appear literally on the wire
      expect(mail.text_part.decoded).to include("Córka budzi się co godzinę.", "jan@example.com")
      expect(mail.html_part.decoded).to include("Córka budzi się co godzinę.")
    end

    it "re-renders the form with errors and sends nothing when fields are missing" do
      expect {
        post contact_path, params: { contact_message: { name: "", email: "", body: "" } }
      }.not_to have_enqueued_mail(ContactMailer, :new_message)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Podaj imię i nazwisko", "Podaj adres e-mail", "Napisz wiadomość")
    end

    it "rejects a malformed address rather than handing it to the mailer" do
      expect {
        post contact_path, params: valid_params.deep_merge(contact_message: { email: "jan(at)example" })
      }.not_to have_enqueued_mail(ContactMailer, :new_message)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Podaj prawidłowy adres e-mail")
    end

    it "keeps what was typed so a rejected form does not have to be filled in twice" do
      post contact_path, params: valid_params.deep_merge(contact_message: { email: "" })

      expect(response.body).to include("Jan Kowalski")
      expect(response.body).to include("Córka budzi się co godzinę.")
    end

    context "with Turnstile turned on" do
      # overrides the always-passes default from spec/support/turnstile.rb
      def turnstile(verified:)
        allow(TurnstileVerificationService).to receive(:call)
          .and_return(instance_double(TurnstileVerificationService, verified?: verified))
      end

      it "sends nothing when Cloudflare will not vouch for the submission" do
        turnstile(verified: false)

        expect {
          post contact_path, params: valid_params
        }.not_to have_enqueued_mail(ContactMailer, :new_message)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Nie udało się potwierdzić, że nie jesteś robotem")
      end

      # the rejected form has to come back with a live widget: the token it just
      # spent cannot be replayed, so a bare form would be unsubmittable
      it "hands a rejected submission a fresh widget and what it typed" do
        turnstile(verified: false)
        allow(TurnstileVerificationService).to receive(:site_key).and_return("0x4AAAAAAER67vZw4kxe-e59")

        post contact_path, params: valid_params

        expect(response.body).to include('data-controller="turnstile"')
        expect(response.body).to include('data-turnstile-action-value="contact"')
        expect(response.body).to include("Jan Kowalski")
      end

      it "sends the mail once Cloudflare vouches for it" do
        turnstile(verified: true)

        expect {
          post contact_path, params: valid_params
        }.to have_enqueued_mail(ContactMailer, :new_message)
      end

      it "checks the token against this page's action and host" do
        expect(TurnstileVerificationService).to receive(:call).with(
          hash_including(action: "contact", hostname: "www.example.com")
        ).and_return(instance_double(TurnstileVerificationService, verified?: true))

        post contact_path, params: valid_params.merge("cf-turnstile-response" => "XXXX.DUMMY.TOKEN.XXXX")
      end
    end

    it "answers a bare post with the form's own errors rather than a 400" do
      post contact_path

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Podaj imię i nazwisko")
    end
  end
end
