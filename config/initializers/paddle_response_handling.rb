# Paddle 2.10 assumes every response body is a JSON object. Cloudflare can
# return HTML (including HTTP 429), which makes the SDK's error handler raise
# NoMethodError instead of a Paddle error. Keep these transport failures within
# the existing Paddle::Error rescue paths, without logging the response body.
module PaddleResponseHandling
  private

  def handle_response(response)
    unless response.status == 204 || response.body.is_a?(Hash)
      raise Paddle::Error, "Paddle returned a non-object response (HTTP #{response.status})"
    end

    super
  end
end

Paddle::Client.singleton_class.prepend(PaddleResponseHandling)
