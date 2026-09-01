require 'rails_helper'

RSpec.describe BrevoSubscriptionService do
  let(:env) do
    { "BREVO_API_KEY" => "xkeysib-test", "BREVO_LIST_ID" => "7", "BREVO_DOI_TEMPLATE_ID" => "3" }
  end

  # Stubs the one HTTP call the service makes and hands the caller the request
  # object, so a spec can assert on what was actually sent to Brevo. Real
  # response classes rather than doubles: the service branches on
  # `is_a?(Net::HTTPSuccess)`, which a double does not answer.
  def stub_brevo(response, &captured)
    allow_any_instance_of(Net::HTTP).to receive(:request) do |_http, request|
      captured&.call(request)
      response
    end
  end

  def created
    Net::HTTPCreated.new("1.1", "201", "Created")
  end

  def bad_request(payload)
    Net::HTTPBadRequest.new("1.1", "400", "Bad Request").tap do |response|
      allow(response).to receive(:body).and_return(payload.to_json)
    end
  end

  def subscribe(email: "rodzic@example.com")
    described_class.call(email: email, redirect_url: "https://sleep.example/").subscribed?
  end

  context "when Brevo is not configured" do
    before { stub_const("ENV", ENV.to_h.except(*env.keys)) }

    it "is not considered configured" do
      expect(described_class).not_to be_configured
    end

    # Unlike Turnstile, an unconfigured Brevo cannot be waved through: there is
    # nowhere for the address to go, and a thank-you would be a lie
    it "fails rather than pretending the address was taken, and says so loudly" do
      expect(Rails.logger).to receive(:error).with(/not configured/)

      expect(subscribe).to be(false)
    end

    it "never calls Brevo" do
      expect_any_instance_of(Net::HTTP).not_to receive(:request)

      subscribe
    end
  end

  context "when a partial configuration is present" do
    # the list and the template are as load-bearing as the key - without either
    # the request cannot be built at all
    it "is not configured with only an API key" do
      stub_const("ENV", ENV.to_h.except(*env.keys).merge("BREVO_API_KEY" => "xkeysib-test"))

      expect(described_class).not_to be_configured
    end

    it "is not configured without the double opt-in template" do
      stub_const("ENV", ENV.to_h.except("BREVO_DOI_TEMPLATE_ID").merge(env.except("BREVO_DOI_TEMPLATE_ID")))

      expect(described_class).not_to be_configured
    end
  end

  context "when Brevo is configured" do
    before { stub_const("ENV", ENV.to_h.merge(env)) }

    it "reports success on a created contact" do
      stub_brevo(created)

      expect(subscribe).to be(true)
    end

    it "posts to the double opt-in endpoint, not the plain contacts one" do
      path = nil
      stub_brevo(created) { |request| path = request.path }

      subscribe

      expect(path).to eq("/v3/contacts/doubleOptinConfirmation")
    end

    it "authenticates with the api-key header rather than a bearer token" do
      headers = nil
      stub_brevo(created) { |request| headers = request }

      subscribe

      expect(headers["api-key"]).to eq("xkeysib-test")
    end

    # the list and template are what turn a bare address into a confirmed
    # subscription, and Brevo wants both as numbers
    it "sends the address, the list, the template and the return address" do
      body = nil
      stub_brevo(created) { |request| body = JSON.parse(request.body) }

      subscribe

      expect(body).to eq(
        "email" => "rodzic@example.com",
        "includeListIds" => [ 7 ],
        "templateId" => 3,
        "redirectionUrl" => "https://sleep.example/"
      )
    end

    # saying "already subscribed" would tell anyone who asks which addresses are
    # on the list, and it is not a failure the visitor can act on either way
    it "treats an address already on the list as success" do
      stub_brevo(bad_request(code: "duplicate_parameter", message: "Contact already exist"))

      expect(subscribe).to be(true)
    end

    it "reports failure on any other refusal, and logs what Brevo said" do
      stub_brevo(bad_request(code: "invalid_parameter", message: "Invalid templateId"))
      expect(Rails.logger).to receive(:warn).with(/invalid_parameter.*Invalid templateId/)

      expect(subscribe).to be(false)
    end

    it "reports failure rather than raising when Brevo cannot be reached" do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Errno::ECONNREFUSED)
      expect(Rails.logger).to receive(:error).with(/could not be completed/)

      expect(subscribe).to be(false)
    end

    it "reports failure rather than raising on an unparseable body" do
      response = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
      allow(response).to receive(:body).and_return("<html>502</html>")
      stub_brevo(response)

      expect(subscribe).to be(false)
    end
  end
end
