require "rails_helper"
require "digest"
require "yaml"

RSpec.describe "Agent skills discovery", type: :request do
  let(:index_path) { "/.well-known/agent-skills/index.json" }
  let(:skill_path) { "/.well-known/agent-skills/sleep-puzzle-guide/SKILL.md" }

  it "publishes a v0.2.0 index with a verifiable, matching skill artifact" do
    get index_path, headers: { "Accept" => "text/markdown", "User-Agent" => "Mozilla/5.0 Version/12.0 Safari/605.1.15" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    index = response.parsed_body
    expect(index.fetch("$schema")).to eq("https://schemas.agentskills.io/discovery/0.2.0/schema.json")
    expect(index.fetch("skills").size).to eq(1)

    skill = index.fetch("skills").first
    expect(skill.fetch("name")).to match(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
    expect(skill.fetch("name").length).to be <= 64
    expect(skill.fetch("type")).to eq("skill-md")
    expect(skill.fetch("description").length).to be_between(1, 1024)
    expect(skill.fetch("url")).to eq(skill_path)
    expect(skill.fetch("digest")).to match(/\Asha256:[a-f0-9]{64}\z/)

    get skill.fetch("url"), headers: { "Accept" => "application/json", "User-Agent" => "Mozilla/5.0 Version/12.0 Safari/605.1.15" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect("sha256:#{Digest::SHA256.hexdigest(response.body)}").to eq(skill.fetch("digest"))
    metadata = YAML.safe_load(response.body.split("---", 3).fetch(1))
    expect(metadata.fetch("name")).to eq(skill.fetch("name"))
    expect(metadata.fetch("description")).to eq(skill.fetch("description"))
  end

  { "/.well-known/agent-skills/index.json" => "application/json",
    "/.well-known/agent-skills/sleep-puzzle-guide/SKILL.md" => "text/markdown" }.each do |path, media_type|
    it "supports HEAD, public caching, and browser clients for #{path}" do
      head path

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(media_type)
      expect(response.body).to be_empty
      expect(response.headers.fetch("Cache-Control")).to include("public", "max-age=300")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(response.headers["Set-Cookie"]).to be_nil
    end
  end

  it "returns 404 for an unknown skill artifact" do
    get "/.well-known/agent-skills/unknown/SKILL.md"

    expect(response).to have_http_status(:not_found)
  end
end
