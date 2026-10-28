require "rails_helper"

RSpec.describe "OAuth and OIDC discovery", type: :request do
  let(:metadata) do
    {
      issuer: "https://accounts.google.com",
      authorization_endpoint: "https://accounts.google.com/o/oauth2/v2/auth",
      token_endpoint: "https://oauth2.googleapis.com/token",
      jwks_uri: "https://www.googleapis.com/oauth2/v3/certs",
      grant_types_supported: [ "authorization_code", "refresh_token" ],
      response_types_supported: [ "code" ],
      subject_types_supported: [ "public" ],
      id_token_signing_alg_values_supported: [ "RS256" ]
    }.stringify_keys
  end

  let(:upstream) { Net::HTTPOK.new("1.1", "200", "OK") }
  let(:http) { instance_double(Net::HTTP) }

  before do
    allow(upstream).to receive(:body).and_return(metadata.to_json)
    allow(Net::HTTP).to receive(:start).with("accounts.google.com", 443,
      use_ssl: true, open_timeout: 5, read_timeout: 5).and_yield(http)
    allow(http).to receive(:get).with("/.well-known/openid-configuration", "Accept" => "application/json").and_return(upstream)
  end

  %w[openid-configuration oauth-authorization-server].each do |document|
    [ nil, "text/html", "text/markdown", "application/json" ].each do |accept|
      it "serves #{document} as public JSON for Accept #{accept.inspect}" do
        get "/.well-known/#{document}", headers: {
          "User-Agent" => "Mozilla/5.0 Version/12.0 Safari/605.1.15",
          **(accept ? { "Accept" => accept } : {})
        }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("application/json")
        expect(response.parsed_body).to eq(metadata)
        expect(response.headers["Cache-Control"]).to include("public", "max-age=3600")
        expect(response.headers["Set-Cookie"]).to be_nil
      end
    end
  end

  it "supports HEAD without a response body" do
    head "/.well-known/openid-configuration"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(response.body).to be_empty
  end

  it "caches successful upstream metadata across both routes" do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    expect(http).to receive(:get).once.and_return(upstream)

    get "/.well-known/openid-configuration"
    expect(response).to have_http_status(:ok)
    get "/.well-known/oauth-authorization-server"
    expect(response.parsed_body).to eq(metadata)
  end

  [ "<html>Unavailable</html>", "[]", '{"issuer":"https://wrong.example"}' ].each do |body|
    it "rejects invalid upstream metadata #{body.inspect}" do
      allow(upstream).to receive(:body).and_return(body)

      get "/.well-known/openid-configuration"

      expect(response).to have_http_status(:service_unavailable)
      expect(response.media_type).to eq("application/json")
      expect(response.headers["Cache-Control"]).to eq("no-store")
    end
  end

  it "rejects an incomplete discovery document" do
    metadata.delete("grant_types_supported")
    allow(upstream).to receive(:body).and_return(metadata.to_json)

    get "/.well-known/openid-configuration"

    expect(response).to have_http_status(:service_unavailable)
  end

  it "rejects non-HTTPS provider endpoints" do
    allow(upstream).to receive(:body).and_return(metadata.merge("token_endpoint" => "http://example.com/token").to_json)

    get "/.well-known/oauth-authorization-server"

    expect(response).to have_http_status(:service_unavailable)
  end

  it "does not follow upstream redirects" do
    allow(http).to receive(:get).and_return(Net::HTTPFound.new("1.1", "302", "Found"))

    get "/.well-known/openid-configuration"

    expect(response).to have_http_status(:service_unavailable)
  end

  it "returns a retryable JSON error when Google times out and recovers on the next request" do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    allow(http).to receive(:get).and_raise(Net::ReadTimeout)

    get "/.well-known/openid-configuration"

    expect(response).to have_http_status(:service_unavailable)
    expect(response.headers["Retry-After"]).to eq("60")
    expect(response.parsed_body).to eq("error" => "Identity provider discovery is temporarily unavailable")

    allow(http).to receive(:get).and_return(upstream)
    get "/.well-known/openid-configuration"
    expect(response).to have_http_status(:ok)
  end
end
