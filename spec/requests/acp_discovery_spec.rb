require "rails_helper"

RSpec.describe "ACP discovery", type: :request do
  let(:configuration) do
    {
      "ACP_PROTOCOL_VERSION" => "2026-04-17",
      "ACP_API_BASE_URL" => "https://commerce.example.com/acp",
      "ACP_SERVICES" => "checkout",
      "ACP_TRANSPORTS" => "rest"
    }
  end

  before { stub_const("ENV", ENV.to_h.merge(configuration)) }

  it "publishes public, cacheable JSON at the origin root" do
    get "/.well-known/acp.json"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(response.headers["Cache-Control"]).to include("public", "max-age=3600")
    expect(response.parsed_body).to eq(
      "protocol" => {
        "name" => "acp", "version" => "2026-04-17", "supported_versions" => [ "2026-04-17" ]
      },
      "api_base_url" => "https://commerce.example.com/acp",
      "transports" => [ "rest" ],
      "capabilities" => { "services" => [ "checkout" ] }
    )
  end

  it "keeps JSON for Markdown requests from older agents" do
    get "/.well-known/acp.json", headers: {
      "Accept" => "text/markdown",
      "User-Agent" => "Mozilla/5.0 Version/12.0 Safari/605.1.15"
    }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(response.parsed_body.dig("protocol", "name")).to eq("acp")
  end

  it "supports HEAD discovery" do
    head "/.well-known/acp.json"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(response.body).to be_empty
  end

  {
    "ACP_API_BASE_URL" => [ "", "/api", "ftp://commerce.example.com", "https://" ],
    "ACP_PROTOCOL_VERSION" => [ "", "1.0", "2026-02-30" ],
    "ACP_SERVICES" => [ "", "browser_checkout" ],
    "ACP_TRANSPORTS" => [ "", "browser" ]
  }.each do |key, values|
    values.each do |value|
      it "does not advertise ACP with #{key}=#{value.inspect}" do
        ENV[key] = value

        get "/.well-known/acp.json"

        expect(response).to have_http_status(:service_unavailable)
        expect(response.parsed_body).to eq("error" => "ACP discovery is not configured")
        expect(response.headers["Cache-Control"]).to eq("no-store")
      end
    end
  end
end
