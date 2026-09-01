require 'rails_helper'

RSpec.describe BrevoApiDelivery do
  let(:delivery) { described_class.new }

  # Captures what would go to Brevo without making the call.
  def payload_for(mail)
    captured = nil
    allow(delivery).to receive(:post) do |payload|
      captured = payload
      instance_double(Net::HTTPCreated).tap { |r| allow(r).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true) }
    end
    delivery.deliver!(mail)
    captured
  end

  before { stub_const("ENV", ENV.to_h.merge("BREVO_API_KEY" => "xkeysib-test")) }

  describe "#deliver!" do
    let(:mail) do
      Mail.new do
        from    "Sleep Puzzle <hello@sleep.test>"
        to      "Dominik <owner@sleep.test>"
        reply_to "visitor@example.com"
        subject "Nowa wiadomość"

        text_part { body "plain body" }
        html_part { content_type "text/html; charset=UTF-8"; body "<p>html body</p>" }
      end
    end

    it "sends both parts of a multipart mail" do
      payload = payload_for(mail)

      expect(payload[:htmlContent]).to eq("<p>html body</p>")
      expect(payload[:textContent]).to eq("plain body")
    end

    it "carries display names, so the client shows a name rather than a bare address" do
      payload = payload_for(mail)

      expect(payload[:sender]).to eq({ email: "hello@sleep.test", name: "Sleep Puzzle" })
      expect(payload[:to]).to eq([ { email: "owner@sleep.test", name: "Dominik" } ])
    end

    it "keeps reply_to, which is what makes answering a notification reach the sender" do
      expect(payload_for(mail)[:replyTo]).to eq({ email: "visitor@example.com" })
    end

    it "omits keys Brevo would reject as empty" do
      payload = payload_for(mail)

      expect(payload).not_to have_key(:cc)
      expect(payload).not_to have_key(:bcc)
      expect(payload).not_to have_key(:attachment)
    end

    it "still finds the body of a single-part mail" do
      plain = Mail.new do
        from "hello@sleep.test"
        to   "owner@sleep.test"
        subject "Plain"
        body "just text"
      end

      payload = payload_for(plain)

      expect(payload[:textContent]).to eq("just text")
      expect(payload).not_to have_key(:htmlContent)
    end

    it "raises when Brevo refuses, so raise_delivery_errors surfaces it and the job retries" do
      refusal = instance_double(Net::HTTPBadRequest, code: "400", body: '{"code":"invalid_parameter"}')
      allow(refusal).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      allow(delivery).to receive(:post).and_return(refusal)

      expect { delivery.deliver!(mail) }
        .to raise_error(described_class::DeliveryError, /400.*invalid_parameter/)
    end

    it "raises rather than hanging when Brevo cannot be reached" do
      allow(delivery).to receive(:post).and_raise(Errno::ECONNRESET)

      expect { delivery.deliver!(mail) }.to raise_error(described_class::DeliveryError, /could not be reached/)
    end

    it "names the blank setting rather than spending a request Brevo will refuse" do
      mail[:from] = ""

      expect { delivery.deliver!(mail) }.to raise_error(described_class::DeliveryError, /MAIL_FROM is blank/)
    end

    it "says so when the key is missing, rather than posting an unauthenticated request" do
      stub_const("ENV", ENV.to_h.except("BREVO_API_KEY"))

      expect { delivery.deliver!(mail) }.to raise_error(described_class::DeliveryError, /BREVO_API_KEY/)
    end
  end
end
