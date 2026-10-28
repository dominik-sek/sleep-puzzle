# Public protocol metadata must be accessible without a session or browser gate.
class AcpDiscoveryController < ActionController::Base
  def show
    version = ENV["ACP_PROTOCOL_VERSION"].to_s.strip
    base_url = ENV["ACP_API_BASE_URL"].to_s.strip
    transports = list("ACP_TRANSPORTS", "rest")
    services = list("ACP_SERVICES")

    unless configured?(version, base_url, transports, services)
      response.headers["Cache-Control"] = "no-store"
      return render json: { error: "ACP discovery is not configured" }, status: :service_unavailable
    end

    expires_in 1.hour, public: true
    render json: {
      protocol: { name: "acp", version: version, supported_versions: [ version ] },
      api_base_url: base_url,
      transports: transports,
      capabilities: { services: services }
    }
  end

  private

  def list(key, default = "")
    ENV.fetch(key, default).split(",").map(&:strip).reject(&:empty?).uniq
  end

  # Do not advertise browser checkout as an ACP API or publish invalid metadata.
  def configured?(version, base_url, transports, services)
    uri = URI.parse(base_url)
    version.match?(/\A\d{4}-\d{2}-\d{2}\z/) && Date.iso8601(version) &&
      uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil? &&
      transports.any? && (transports - %w[rest mcp]).empty? &&
      services.any? && (services - %w[checkout orders delegate_payment carts]).empty?
  rescue URI::InvalidURIError, Date::Error
    false
  end
end
