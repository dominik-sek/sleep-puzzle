# Asks Cloudflare whether a Turnstile token is genuine.
#
# The token the widget puts in the form proves nothing on its own - it has to be
# redeemed against siteverify, from here rather than the browser, because only
# this side holds the secret. Tokens are single use, so a replay of one that has
# already been redeemed comes back as a failure.
class TurnstileVerificationService < ApplicationService
  VERIFY_URL = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify").freeze

  # Cloudflare answers in milliseconds; anything near this is an outage, and a
  # visitor should be told to try again rather than watch the form hang.
  TIMEOUT = 5

  # Anything that means we never got an answer, as opposed to got a "no".
  NETWORK_ERRORS = [ Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError, OpenSSL::SSL::SSLError, IOError ].freeze

  class << self
    # The secret is what makes verification possible at all, so its absence - not
    # the site key's - is what decides whether the check can run.
    def configured?
      secret.present?
    end

    def secret
      ENV["TURNSTILE_SECRET"].presence
    end

    # Public by design: it ships in the page for the widget to render itself.
    def site_key
      ENV["TURNSTILE_SITE_KEY"].presence
    end
  end

  # @param token [String] the cf-turnstile-response field the widget posted
  # @param action [String] the surface the widget was rendered for; a token minted
  #   somewhere else must not be spendable here
  # @param hostname [String] the host the form was served from
  # @param remote_ip [String] optional, and only ever used by Cloudflare's scoring
  def initialize(token:, action:, hostname: nil, remote_ip: nil)
    @token = token
    @action = action
    @hostname = hostname
    @remote_ip = remote_ip
  end

  # mirrors BookingPaymentCheckService: .call does the work, then you ask
  def call
    self
  end

  def verified?
    # Nothing to verify against. Loud, because a deploy that lost the secret has
    # quietly stopped checking anything.
    unless self.class.configured?
      Rails.logger.warn("Turnstile is not configured (TURNSTILE_SECRET is unset) - skipping verification")
      return true
    end

    return false if @token.blank?

    payload = response_payload
    return false unless payload

    payload["success"] == true && action_matches?(payload) && hostname_matches?(payload)
  end

  private

  # A token is minted for the widget's action, so one lifted from another form on
  # the site should not open this one.
  def action_matches?(payload)
    return true if @action.blank? || payload["action"].blank?

    payload["action"] == @action
  end

  # Cloudflare already refuses to issue tokens outside the widget's configured
  # domains; checking here as well means a token that somehow was still cannot be
  # spent against a different host.
  def hostname_matches?(payload)
    return true if @hostname.blank? || payload["hostname"].blank?

    payload["hostname"] == @hostname
  end

  # nil on anything that stops us getting an answer, which the caller treats as
  # "not verified": an unreachable Cloudflare should hold the form rather than
  # wave everything through, and the rate limit is what keeps that from being a
  # way to hammer the inbox.
  def response_payload
    response = post_to_cloudflare
    payload = JSON.parse(response.body)

    log_failure(payload) unless payload["success"]

    payload
  rescue JSON::ParserError, *NETWORK_ERRORS => e
    Rails.logger.error("Turnstile verification could not be completed: #{e.class}: #{e.message}")
    nil
  end

  def post_to_cloudflare
    http = Net::HTTP.new(VERIFY_URL.host, VERIFY_URL.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    request = Net::HTTP::Post.new(VERIFY_URL.path)
    request.set_form_data(form_data)

    http.request(request)
  end

  def form_data
    {
      "secret" => self.class.secret,
      "response" => @token,
      "remoteip" => @remote_ip
    }.compact
  end

  # The codes say whether this was a bot, a replayed token or our own
  # misconfiguration, and they are the only place that distinction survives.
  def log_failure(payload)
    Rails.logger.info("Turnstile rejected a token: #{Array(payload['error-codes']).join(', ').presence || 'no error codes'}")
  end
end
