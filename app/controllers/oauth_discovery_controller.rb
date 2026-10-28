# Stateless discovery must be readable without a browser or a signed-in session.
class OauthDiscoveryController < ActionController::API
  def show
    metadata = GoogleOidcDiscovery.call
    expires_in 1.hour, public: true
    render json: metadata
  rescue GoogleOidcDiscovery::Unavailable
    response.headers["Cache-Control"] = "no-store"
    response.headers["Retry-After"] = "60"
    render json: { error: "Identity provider discovery is temporarily unavailable" }, status: :service_unavailable
  end
end
