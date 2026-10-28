require "rails_helper"

RSpec.describe "UCP discovery", type: :request do
  [ nil, "application/json", "text/html", "text/markdown" ].each do |accept|
    it "serves JSON at the well-known URL for Accept #{accept.inspect}" do
      get "/.well-known/ucp", headers: accept ? { "Accept" => accept } : {}

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      profile = response.parsed_body
      expect(profile).to include("protocol_version", "services", "capabilities", "endpoints")
      expect(profile.fetch("ucp")).to include(
        "version" => profile.fetch("protocol_version"),
        "services" => profile.fetch("services"),
        "capabilities" => profile.fetch("capabilities"),
        "payment_handlers" => {}
      )
      expect(profile.fetch("capabilities").keys).to eq([ "com.sleeppuzzle.shopping.browser_checkout" ])
      expect(profile.fetch("endpoints")).to include("checkout" => "https://sleeppuzzle.com/cart")
    end
  end

  it "allows agents outside the modern-browser gate without initiating a payment" do
    expect(PaddlePriceCatalogService).not_to receive(:call)
    expect {
      get "/.well-known/ucp", headers: { "User-Agent" => "Mozilla/5.0 Version/12.0 Safari/605.1.15" }
    }.not_to change(Order, :count)

    expect(response).to have_http_status(:ok)
    expect(response.headers["Set-Cookie"]).to be_nil
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "serves every advertised specification and schema without redirects or authentication" do
    get "/.well-known/ucp"
    profile = response.parsed_body.fetch("ucp")
    declarations = profile.fetch("services").merge(profile.fetch("capabilities"))

    declarations.each do |name, entries|
      entries.each do |entry|
        %w[spec schema].each do |field|
          uri = URI(entry.fetch(field))
          expect(uri.scheme).to eq("https")
          expect(name).to start_with(uri.host.split(".").reverse.join(".")) if field == "schema"

          get uri.path, headers: { "Accept" => "text/markdown" }

          expect(response).to have_http_status(:ok)
          if field == "schema"
            expect(response.media_type).to eq("application/json")
            expect(response.parsed_body).to be_a(Hash)
          else
            expect(response.media_type).to eq("text/markdown")
            expect(response.body).to include("Paddle", "browser", "consent")
          end
        end
      end
    end
  end

  it "answers HEAD with the same JSON content type and no body" do
    head "/.well-known/ucp"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(response.body).to be_empty
  end
end
