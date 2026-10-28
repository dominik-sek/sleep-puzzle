require "net/http"

# A mirror of the provider used by OmniAuth, not a Sleep Puzzle token issuer.
# Keep Google's issuer and endpoints intact; never derive them from request input.
class GoogleOidcDiscovery < ApplicationService
  ISSUER = "https://accounts.google.com".freeze
  DISCOVERY_URI = URI("#{ISSUER}/.well-known/openid-configuration").freeze
  CACHE_KEY = "google-oidc-discovery/v1".freeze

  class Unavailable < StandardError; end

  def call
    Rails.cache.fetch(CACHE_KEY, expires_in: 1.hour) do
      response = Net::HTTP.start(DISCOVERY_URI.host, DISCOVERY_URI.port,
        use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
        http.get(DISCOVERY_URI.request_uri, "Accept" => "application/json")
      end
      raise Unavailable unless response.is_a?(Net::HTTPSuccess)

      metadata = JSON.parse(response.body)
      raise Unavailable unless valid?(metadata)

      metadata
    end
  rescue JSON::ParserError, Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse
    raise Unavailable
  end

  private

  def valid?(metadata)
    metadata.is_a?(Hash) && metadata["issuer"] == ISSUER &&
      %w[authorization_endpoint token_endpoint jwks_uri].all? { |key| https_url?(metadata[key]) } &&
      %w[grant_types_supported response_types_supported subject_types_supported id_token_signing_alg_values_supported].all? do |key|
        values = metadata[key]
        values.is_a?(Array) && values.any? && values.all? { |value| value.is_a?(String) && value.present? }
      end
  end

  def https_url?(value)
    return false unless value.is_a?(String)

    uri = URI.parse(value)
    uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? && uri.fragment.nil?
  rescue URI::InvalidURIError
    false
  end
end
