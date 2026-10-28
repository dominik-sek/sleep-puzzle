require "rails_helper"

RSpec.describe "API catalog", type: :request do
  before { host! "sleeppuzzle.com" }

  [ nil, "application/linkset+json, application/json", "text/html", "text/markdown" ].each do |accept|
    it "serves a Linkset without authentication for Accept #{accept.inspect}" do
      get "/.well-known/api-catalog", headers: accept ? { "Accept" => accept } : {}

      expect(response).to have_http_status(:ok)
      expect(response.content_type.split(";").first).to eq("application/linkset+json")
      expect(response.content_type).to include('profile="https://www.rfc-editor.org/info/rfc9727"')

      entries = JSON.parse(response.body).fetch("linkset")
      expect(entries.size).to eq(1)
      expect(entries.first).to include("anchor" => "https://sleeppuzzle.com/llms.txt")
      expect(entries.first.fetch("service-desc")).to include(
        include("href" => "https://sleeppuzzle.com/openapi.json", "type" => "application/json")
      )
      expect(entries.first.fetch("service-doc")).to include(
        include("href" => "https://sleeppuzzle.com/api-docs.txt", "type" => "text/plain")
      )
      expect(entries.first.fetch("status")).to include(
        include("href" => "https://sleeppuzzle.com/up")
      )
    end
  end

  it "answers HEAD with the catalog discovery link and no body" do
    head "/.well-known/api-catalog"

    expect(response).to have_http_status(:ok)
    expect(response.content_type.split(";").first).to eq("application/linkset+json")
    expect(response.headers["Link"]).to eq(
      '<https://sleeppuzzle.com/.well-known/api-catalog>; rel="api-catalog"; type="application/linkset+json"'
    )
    expect(response.body).to be_empty
  end

  it "serves the linked specification, docs, and public endpoints" do
    get "/openapi.json"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    specification = response.parsed_body
    expect(specification.fetch("openapi")).to eq("3.1.0")
    expect(specification.fetch("servers")).to include("url" => "https://sleeppuzzle.com")

    get "/api-docs.txt"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/plain")
    expect(response.body).to include("https://sleeppuzzle.com/openapi.json")

    specification.fetch("paths").each do |path, operations|
      next unless operations.key?("get")

      get path

      expect(response).to have_http_status(:ok), "GET #{path} returned #{response.status}"
      expect(operations.fetch("get").fetch("responses").fetch("200").fetch("content")).to have_key(response.media_type)
    end
  end

  it "does not accept writes to the catalog" do
    post "/.well-known/api-catalog"

    expect(response).to have_http_status(:not_found)
  end
end
