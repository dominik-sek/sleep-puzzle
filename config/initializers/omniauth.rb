# The redirect_uri handed to Google has to point back at whichever host the login
# started from — localhost in normal development, the Cloudflare tunnel when
# testing Paddle webhooks — so outside production we derive it from the request.
OmniAuth.config.full_host = if Rails.env.production?
  "https://domain.com" # todo: change host after domain done
else
  lambda do |env|
    request = ActionDispatch::Request.new(env)
    # cloudflared terminates TLS and forwards plain HTTP, so trust its scheme header
    scheme = request.headers["X-Forwarded-Proto"].presence || request.scheme
    "#{scheme}://#{request.host_with_port}"
  end
end
