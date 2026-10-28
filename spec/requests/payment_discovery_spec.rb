require "rails_helper"

RSpec.describe "Payment discovery", type: :request do
  [ nil, "application/json", "text/html", "text/markdown" ].each do |accept|
    it "serves root OpenAPI as JSON without sign-in for Accept #{accept.inspect}" do
      get "/openapi.json", headers: accept ? { "Accept" => accept } : {}

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      document = response.parsed_body
      expect(document.fetch("openapi")).to eq("3.1.0")
      expect(document.fetch("x-service-info").fetch("categories")).to include("media")

      %w[/orders /bookings].each do |path|
        operation = document.fetch("paths").fetch(path).fetch("post")
        expect(Rails.application.routes.recognize_path(path, method: :post)).to include(action: "create")
        expect(operation.fetch("x-payment-info")).to include(
          "intent" => "charge", "method" => "card", "amount" => nil
        )
        expect(operation.fetch("x-payment-info").fetch("description")).to include("Paddle")
        expect(operation.fetch("security")).to eq([ { "browserSession" => [] } ])
        expect(operation.fetch("requestBody").fetch("content")).to have_key("application/x-www-form-urlencoded")
      end
    end
  end

  it "answers HEAD and permits an older browser user agent" do
    head "/openapi.json", headers: { "User-Agent" => "Mozilla/5.0 Version/12.0 Safari/605.1.15" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(response.body).to be_empty
  end

  it "keeps free content free and describes the current browser checkout limitation" do
    get "/openapi.json"

    document = response.parsed_body
    document.fetch("paths").each_value do |operations|
      next unless operations.key?("get")

      expect(operations.fetch("get")).not_to have_key("x-payment-info")
    end
    expect(document.fetch("info").fetch("description")).to include("does not accept MPP")

    get "/api-docs.txt"

    expect(response.body).to include("amount: null", "Paddle", "MPP Authorization: Payment")
  end
end
