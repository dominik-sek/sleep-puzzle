require 'rails_helper'

RSpec.describe TurnstileVerificationService do
  let(:secret) { "1x0000000000000000000000000000000AA" }

  # Stubs the one HTTP call the service makes, and hands the caller the request
  # object so a spec can assert on what was actually sent to Cloudflare.
  def stub_cloudflare(payload, &captured)
    response = instance_double(Net::HTTPResponse, body: payload.to_json)

    allow_any_instance_of(Net::HTTP).to receive(:request) do |_http, request|
      captured&.call(request)
      response
    end
  end

  def verify(**overrides)
    described_class.call(**{ token: "XXXX.DUMMY.TOKEN.XXXX", action: "contact" }.merge(overrides)).verified?
  end

  context "when no secret is configured" do
    before { stub_const("ENV", ENV.to_h.except("TURNSTILE_SECRET")) }

    it "is not considered configured" do
      expect(described_class).not_to be_configured
    end

    # local development without a key still has a working form; the warning is
    # what makes a deploy that lost the secret findable
    it "lets the submission through rather than blocking the form, and says so" do
      expect(Rails.logger).to receive(:warn).with(/not configured/)

      expect(verify).to be(true)
    end

    it "never calls Cloudflare" do
      expect_any_instance_of(Net::HTTP).not_to receive(:request)

      verify
    end
  end

  context "when a secret is configured" do
    before { stub_const("ENV", ENV.to_h.merge("TURNSTILE_SECRET" => secret)) }

    it "accepts a token Cloudflare confirms" do
      stub_cloudflare({ "success" => true, "action" => "contact", "hostname" => "sleeppuzzle.pl" })

      expect(verify(hostname: "sleeppuzzle.pl")).to be(true)
    end

    it "rejects a token Cloudflare refuses" do
      stub_cloudflare({ "success" => false, "error-codes" => [ "invalid-input-response" ] })

      expect(verify).to be(false)
    end

    it "rejects a token that has already been spent" do
      stub_cloudflare({ "success" => false, "error-codes" => [ "timeout-or-duplicate" ] })

      expect(verify).to be(false)
    end

    it "posts the secret, the token and the caller's ip, form encoded" do
      sent = nil
      stub_cloudflare({ "success" => true }) { |request| sent = request }

      verify(remote_ip: "203.0.113.7")

      expect(sent.path).to eq("/turnstile/v0/siteverify")
      expect(sent["content-type"]).to eq("application/x-www-form-urlencoded")
      expect(URI.decode_www_form(sent.body).to_h).to eq(
        "secret" => secret,
        "response" => "XXXX.DUMMY.TOKEN.XXXX",
        "remoteip" => "203.0.113.7"
      )
    end

    it "leaves out an ip it was never given rather than sending a blank one" do
      sent = nil
      stub_cloudflare({ "success" => true }) { |request| sent = request }

      verify

      expect(URI.decode_www_form(sent.body).to_h).not_to have_key("remoteip")
    end

    # a token minted for another widget on the site must not open this one
    it "rejects a token issued for a different action" do
      stub_cloudflare({ "success" => true, "action" => "newsletter" })

      expect(verify(action: "contact")).to be(false)
    end

    it "rejects a token issued for a different host" do
      stub_cloudflare({ "success" => true, "hostname" => "phisher.example" })

      expect(verify(hostname: "sleeppuzzle.pl")).to be(false)
    end

    it "does not ask Cloudflare about a submission that carried no token at all" do
      expect_any_instance_of(Net::HTTP).not_to receive(:request)

      expect(verify(token: nil)).to be(false)
    end

    # holding the form beats waving everything through; the rate limit keeps an
    # outage from becoming a way to hammer the inbox
    it "fails closed when Cloudflare cannot be reached" do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Timeout::Error)

      expect(verify).to be(false)
    end

    it "fails closed on a response it cannot parse" do
      allow_any_instance_of(Net::HTTP).to receive(:request)
        .and_return(instance_double(Net::HTTPResponse, body: "<html>502</html>"))

      expect(verify).to be(false)
    end

    it "logs why a token was refused, since the codes survive nowhere else" do
      stub_cloudflare({ "success" => false, "error-codes" => [ "invalid-input-secret" ] })
      expect(Rails.logger).to receive(:info).with(/invalid-input-secret/)

      verify
    end
  end
end
