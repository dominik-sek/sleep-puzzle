# Hands an address to Brevo so it can send the confirmation mail.
#
# The list, the consent record, the confirmation mail, the unsubscribe link and
# the bounce handling are all Brevo's — that is the whole point of buying rather
# than building this. Nothing about a subscriber is stored here, so there is no
# model, no table and no unsubscribe route of our own to keep in step.
#
# It posts to the *double opt-in* endpoint rather than plain /contacts, which is
# the difference between "Brevo mails them a confirmation link" and "we added
# them to a marketing list because someone typed their address into a box". The
# design says as much on the thank-you state — "check your inbox to confirm" —
# and an unconfirmed address is not consent worth having.
#
# Called from the browser's request, not a job: the visitor is looking at a
# spinner, and a queued signup would show them a thank-you for something that
# might still fail.
class BrevoSubscriptionService < ApplicationService
  ENDPOINT = URI("https://api.brevo.com/v3/contacts/doubleOptinConfirmation").freeze

  # Long enough for a slow API, short enough that a visitor is not left watching
  # the button spin. Brevo answers well inside this.
  TIMEOUT = 5

  # Anything that means we never got an answer, as opposed to got a "no". Same
  # list as TurnstileVerificationService, for the same reason.
  NETWORK_ERRORS = [ Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError, OpenSSL::SSL::SSLError, IOError ].freeze

  # Brevo says this when the address is already on the list. It is not a failure
  # from where the visitor is standing, and saying so would tell anyone who asks
  # which addresses are subscribed — so it is treated as success.
  ALREADY_SUBSCRIBED_CODE = "duplicate_parameter"

  class << self
    # All three are required. The key authorises the call, the list says what
    # they are subscribing *to*, and the template is the confirmation mail —
    # without any one of them the request cannot be made at all.
    def configured?
      api_key.present? && list_id.present? && template_id.present?
    end

    def api_key
      ENV["BREVO_API_KEY"].presence
    end

    # Brevo's ids are numeric and arrive from the environment as strings.
    def list_id
      ENV["BREVO_LIST_ID"].presence&.to_i
    end

    # The double opt-in template, built in Brevo. It is the one that has to carry
    # the confirmation link, so a plain campaign template will not do.
    def template_id
      ENV["BREVO_DOI_TEMPLATE_ID"].presence&.to_i
    end
  end

  # @param email [String] already validated by NewsletterSignup
  # @param redirect_url [String] where Brevo sends them after they confirm
  def initialize(email:, redirect_url:)
    @email = email
    @redirect_url = redirect_url
  end

  # mirrors TurnstileVerificationService: .call does the work, then you ask
  def call
    self
  end

  def subscribed?
    # Loud, because a deploy that lost one of these has quietly stopped
    # collecting subscribers while still showing everyone a thank-you.
    unless self.class.configured?
      Rails.logger.error("Brevo is not configured (BREVO_API_KEY / BREVO_LIST_ID / BREVO_DOI_TEMPLATE_ID) — subscription dropped")
      return false
    end

    response = post_to_brevo
    return false unless response

    # 201 on a new address, 204 on one Brevo has seen before
    return true if response.is_a?(Net::HTTPSuccess)

    already_subscribed?(response)
  rescue *NETWORK_ERRORS => e
    Rails.logger.error("Brevo subscription could not be completed: #{e.class}: #{e.message}")
    false
  end

  private

  # An address already on the list is a no-op, not an error — see
  # ALREADY_SUBSCRIBED_CODE.
  def already_subscribed?(response)
    payload = JSON.parse(response.body.to_s)

    if payload["code"] == ALREADY_SUBSCRIBED_CODE
      true
    else
      Rails.logger.warn("Brevo refused a subscription: #{response.code} #{payload['code']} #{payload['message']}")
      false
    end
  rescue JSON::ParserError
    Rails.logger.warn("Brevo refused a subscription: #{response.code} (unparseable body)")
    false
  end

  def post_to_brevo
    http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    request = Net::HTTP::Post.new(ENDPOINT.path)
    request["api-key"] = self.class.api_key
    request["content-type"] = "application/json"
    request["accept"] = "application/json"
    request.body = payload.to_json

    http.request(request)
  end

  def payload
    {
      email: @email,
      includeListIds: [ self.class.list_id ],
      templateId: self.class.template_id,
      redirectionUrl: @redirect_url
    }
  end
end
