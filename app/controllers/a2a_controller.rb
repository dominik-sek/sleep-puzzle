# Machine-facing, stateless discovery: no browser gate, session or CSRF token.
class A2aController < ActionController::API
  RESOURCE_DIRECTORY = <<~TEXT.freeze
    Sleep Puzzle public resources (Polish; English under /en):
    Resource index: https://sleeppuzzle.com/llms.txt
    Full articles: https://sleeppuzzle.com/llms-full.txt
    Blog: https://sleeppuzzle.com/blog | https://sleeppuzzle.com/en/blog
    Audio programmes: https://sleeppuzzle.com/audioprocesses | https://sleeppuzzle.com/en/audioprocesses
    Bedtime stories: https://sleeppuzzle.com/stories | https://sleeppuzzle.com/en/stories
    Consultations: https://sleeppuzzle.com/bookings | https://sleeppuzzle.com/en/bookings
    This guide returns public links only. Follow the website to purchase or book a consultation.
  TEXT

  def card
    expires_in 1.hour, public: true
    render json: Rails.root.join("config/agent_card.json").read
  end

  def message
    rpc = JSON.parse(request.raw_post)
    unless rpc.is_a?(Hash) && rpc["jsonrpc"] == "2.0" && rpc["method"].is_a?(String) &&
        (rpc["id"].is_a?(String) || rpc["id"].is_a?(Numeric))
      return rpc_error(nil, -32600, "Invalid request")
    end

    return rpc_error(rpc["id"], -32601, "Method not found") unless rpc["method"] == "SendMessage"

    message = rpc["params"].is_a?(Hash) ? rpc["params"]["message"] : nil
    return rpc_error(rpc["id"], -32602, "A user message with text parts is required") unless valid_message?(message)
    return rpc_error(rpc["id"], -32001, "Task not found") if message["taskId"].present?

    render json: {
      jsonrpc: "2.0", id: rpc["id"],
      result: {
        message: {
          messageId: SecureRandom.uuid,
          contextId: message["contextId"].presence || SecureRandom.uuid,
          role: "ROLE_AGENT",
          parts: [ { text: RESOURCE_DIRECTORY } ]
        }
      }
    }
  rescue JSON::ParserError
    rpc_error(nil, -32700, "Invalid JSON payload")
  end

  private

  def valid_message?(message)
    message.is_a?(Hash) && message["messageId"].is_a?(String) && message["messageId"].present? &&
      message["role"] == "ROLE_USER" && message["parts"].is_a?(Array) && message["parts"].any? &&
      message["parts"].all? { |part| part.is_a?(Hash) && part["text"].is_a?(String) && (part.keys & %w[text raw url data]) == [ "text" ] } &&
      (!message.key?("contextId") || message["contextId"].is_a?(String))
  end

  def rpc_error(id, code, message)
    render json: { jsonrpc: "2.0", id: id, error: { code: code, message: message } }
  end
end
