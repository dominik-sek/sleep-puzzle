# An Action Mailer delivery method that posts to Brevo's transactional API
# instead of speaking SMTP.
#
# Render drops outbound SMTP: the connection neither resolves badly nor is
# refused, it just hangs until Net::OpenTimeout. Nothing about that is fixable
# from this side, and it is not specific to a port — so rather than hunting for
# one that is allowed, this goes out over HTTPS to the same api.brevo.com that
# BrevoSubscriptionService already reaches from the same instance. 443 is not a
# port anyone blocks.
#
# Registered in config/initializers/brevo_api_delivery.rb and selected in
# config/environments/production.rb. SMTP is still there and still works
# anywhere outbound 587 is allowed, which is why the settings and the
# `:smtp` branch have not been removed.
class BrevoApiDelivery
  ENDPOINT = URI("https://api.brevo.com/v3/smtp/email").freeze

  # Generous next to BrevoSubscriptionService's 5s, because nobody is watching a
  # spinner here — this runs in a job, and a slow send that succeeds beats a
  # fast one that has to be retried.
  TIMEOUT = 15

  # Same list as BrevoSubscriptionService: everything that means we never got an
  # answer, as opposed to got a "no".
  NETWORK_ERRORS = [ Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError, OpenSSL::SSL::SSLError, IOError ].freeze

  class DeliveryError < StandardError; end

  attr_accessor :settings

  def self.api_key
    ENV["BREVO_API_KEY"].presence
  end

  def self.configured?
    api_key.present?
  end

  # Action Mailer hands the delivery method its settings hash on every delivery.
  def initialize(settings = {})
    @settings = settings
  end

  def deliver!(mail)
    raise DeliveryError, "BREVO_API_KEY is not set" unless self.class.configured?

    response = post(payload_for(mail))

    # 201 with a messageId is the documented success. Anything else is worth
    # raising on: raise_delivery_errors is true in production, so this surfaces
    # in the job and gets retried rather than being lost.
    unless response.is_a?(Net::HTTPSuccess)
      raise DeliveryError, "Brevo refused the message: #{response.code} #{response.body}"
    end

    mail
  rescue *NETWORK_ERRORS => e
    raise DeliveryError, "Brevo could not be reached: #{e.class}: #{e.message}"
  end

  private

  def payload_for(mail)
    {
      sender: address(mail[:from])&.first,
      to: address(mail[:to]),
      cc: address(mail[:cc]).presence,
      bcc: address(mail[:bcc]).presence,
      replyTo: address(mail[:reply_to])&.first,
      subject: mail.subject,
      htmlContent: body_of(mail, "text/html"),
      textContent: body_of(mail, "text/plain"),
      attachment: attachments_of(mail).presence
    }.compact
  end

  # Mail::Field#addrs carries the display name alongside the address, which is
  # what puts "Sleep Puzzle <hello@…>" in the client rather than a bare address.
  def address(field)
    return nil if field.nil?

    field.addrs.map do |addr|
      { email: addr.address, name: addr.display_name }.compact
    end
  end

  # These mails are all multipart html+text. A single-part mail has no
  # html_part/text_part at all, so fall back to the body when the mime type is
  # the one being asked for — otherwise a plain-text-only mail would go out
  # with no content whatsoever.
  def body_of(mail, mime_type)
    part = mail.multipart? ? mail.find_first_mime_type(mime_type) : mail
    return nil unless part

    # A part carrying no Content-Type at all is text/plain, per RFC 2045. Mail
    # reports that as a nil mime_type rather than filling the default in, so
    # without this a single-part mail goes out with no content at all.
    return nil unless (part.mime_type || "text/plain") == mime_type

    part.body.decoded
  end

  # Nothing sends attachments today. Supported anyway so that adding one later
  # is not a silent drop.
  def attachments_of(mail)
    mail.attachments.map do |attachment|
      { name: attachment.filename, content: Base64.strict_encode64(attachment.body.decoded) }
    end
  end

  def post(payload)
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
end
