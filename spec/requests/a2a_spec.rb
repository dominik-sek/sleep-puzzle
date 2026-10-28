require "rails_helper"

RSpec.describe "A2A discovery", type: :request do
  def send_rpc(payload)
    post "/a2a", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
  end

  def user_message
    { messageId: "discovery-1", role: "ROLE_USER", parts: [ { text: "Find sleep resources" } ] }
  end

  [ nil, "application/json", "text/html", "text/markdown" ].each do |accept|
    it "serves a public JSON card for Accept #{accept.inspect}" do
      get "/.well-known/agent-card.json", headers: {
        "Accept" => accept.to_s, "User-Agent" => "Mozilla/5.0 Version/12.0 Safari/605.1.15"
      }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      card = response.parsed_body
      %w[name version description].each { |field| expect(card[field]).to be_present }
      expect(card.fetch("supportedInterfaces")).to eq([
        { "url" => "https://sleeppuzzle.com/a2a", "protocolBinding" => "JSONRPC", "protocolVersion" => "1.0" }
      ])
      expect(card.fetch("capabilities")).to include("streaming" => false, "pushNotifications" => false)
      expect(card.fetch("defaultInputModes")).to include("text/plain")
      expect(card.fetch("defaultOutputModes")).to include("text/plain")
      expect(card.fetch("skills")).not_to be_empty
      card.fetch("skills").each do |skill|
        %w[id name description tags].each { |field| expect(skill[field]).to be_present }
      end
      expect(response.headers["Cache-Control"]).to include("public", "max-age=3600")
      expect(response.headers["Set-Cookie"]).to be_nil
    end
  end

  it "supports HEAD discovery" do
    head "/.well-known/agent-card.json"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(response.body).to be_empty
  end

  it "serves the advertised skill without signing in or a CSRF token" do
    send_rpc(jsonrpc: "2.0", id: "request-1", method: "SendMessage", params: { message: user_message.merge(contextId: "context-1") })

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body).to include("jsonrpc" => "2.0", "id" => "request-1")
    message = body.fetch("result").fetch("message")
    expect(message).to include("role" => "ROLE_AGENT", "contextId" => "context-1")
    expect(message.fetch("messageId")).to be_present
    expect(message.fetch("parts").first.fetch("text")).to include(
      "https://sleeppuzzle.com/llms.txt", "https://sleeppuzzle.com/en/bookings"
    )
  end

  it "returns a protocol error for unsupported methods" do
    send_rpc(jsonrpc: "2.0", id: 2, method: "SendStreamingMessage")

    expect(response.parsed_body).to include("id" => 2, "error" => { "code" => -32601, "message" => "Method not found" })
  end

  it "rejects invalid envelopes" do
    send_rpc([ { jsonrpc: "2.0", id: 1, method: "SendMessage" } ])

    expect(response.parsed_body.fetch("error").fetch("code")).to eq(-32600)
  end

  [ nil, {}, { messageId: "1", role: "ROLE_USER", parts: [ nil ] },
    { messageId: "1", role: "ROLE_USER", parts: [ { text: "hello", data: {} } ] } ].each do |message|
    it "rejects invalid message #{message.inspect}" do
      send_rpc(jsonrpc: "2.0", id: 3, method: "SendMessage", params: { message: message })

      expect(response.parsed_body.fetch("error").fetch("code")).to eq(-32602)
    end
  end

  it "does not pretend to retain tasks" do
    send_rpc(jsonrpc: "2.0", id: 4, method: "SendMessage", params: { message: user_message.merge(taskId: "missing") })

    expect(response.parsed_body.fetch("error").fetch("code")).to eq(-32001)
  end

  it "returns a parse error for invalid JSON" do
    post "/a2a", params: "{", headers: { "CONTENT_TYPE" => "application/json" }

    expect(response.parsed_body.fetch("error").fetch("code")).to eq(-32700)
  end
end
