# The redirect_uri handed to Google has to point back at whichever host the login
# started from - localhost in normal development, the Cloudflare tunnel when
# testing Paddle webhooks, the real domain in production, where APP_HOST pins it
# rather than trusting a header. A lambda, not a string, because it is evaluated
# per request: an ENV lookup at boot would also run during `assets:precompile` in
# the Docker build, where APP_HOST isn't set.
OmniAuth.config.full_host = lambda do |env|
  app_host = ENV["APP_HOST"].presence

  if Rails.env.production? && app_host
    "https://#{app_host}"
  else
    request = ActionDispatch::Request.new(env)
    # cloudflared terminates TLS and forwards plain HTTP, so trust its scheme header
    scheme = request.headers["X-Forwarded-Proto"].presence || request.scheme
    "#{scheme}://#{request.host_with_port}"
  end
end
