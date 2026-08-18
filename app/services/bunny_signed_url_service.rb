# Mints a playable URL for a file on the Bunny CDN.
#
# The pull zone in front of the audio storage zone is public — anyone who guesses
# a filename gets the recording — so the zone has Token Authentication switched
# on and refuses every request without a valid token. Signing one here is what
# turns "this person owns the product", decided in ProductsController#stream,
# into a URL Bunny will actually serve.
#
# The algorithm is Bunny's advanced token authentication: HMAC-SHA256 over the
# path and the expiry, base64url with the padding stripped, prefixed "HS256-".
# A signature that is subtly wrong fails as a 403 from someone else's server
# rather than as anything debuggable from here, so the spec checks this against
# the test vectors Bunny publishes alongside its own reference implementations.
class BunnySignedUrlService < ApplicationService
  # Long enough that someone who starts a recording, pauses to settle a child and
  # comes back can still seek. Seeking is a fresh Range request against the same
  # signed URL, so a short window would expire mid-recording — the one moment
  # this must not break — rather than at a page load, where it would at least be
  # obvious what happened.
  DEFAULT_TTL = 6.hours

  class << self
    def configured?
      token.present? && host.present?
    end

    def token
      ENV["BUNNY_CDN_TOKEN"].presence
    end

    # Bunny shows the pull zone hostname as a full URL, so that is what tends to
    # get pasted into the environment. Only the host belongs in a signed URL, and
    # a trailing slash would sign a path with a doubled one.
    def host
      ENV["BUNNY_CDN_HOST"].presence&.sub(%r{\Ahttps?://}i, "")&.delete_suffix("/").presence
    end
  end

  # @param path [String] the file's path inside the storage zone, as stored on
  #   Product#cdn_path
  # @param expires_in [ActiveSupport::Duration] how long the minted URL stays good
  def initialize(path, expires_in: DEFAULT_TTL)
    @path = path
    @expires_in = expires_in
  end

  # nil rather than an unsigned URL when there is no path or nothing to sign it
  # with: an unsigned URL is a guaranteed 403, so handing one back would turn a
  # missing environment variable into a broken player instead of a caller that
  # can tell there is no file to offer.
  def call
    return unless self.class.configured?
    return if @path.blank?

    "https://#{self.class.host}#{signature_path}?token=#{signature}&expires=#{expires}"
  end

  private

  # Bunny signs the path exactly as it appears in the URL, leading slash and all.
  # Product#cdn_path is normalised to that shape on write, so this only has to
  # cope with what a caller passes in directly.
  def signature_path
    @signature_path ||= @path.start_with?("/") ? @path : "/#{@path}"
  end

  def expires
    @expires ||= (Time.current + @expires_in).to_i
  end

  # Only the path and the expiry go into the hash. Bunny's scheme can also bind a
  # token to an IP, which is deliberately not used: a phone that moves from wi-fi
  # to mobile data mid-recording changes address, and the buyer would get a 403
  # for doing nothing wrong.
  def signature
    digest = OpenSSL::HMAC.digest("SHA256", self.class.token, "#{signature_path}#{expires}")

    "HS256-#{Base64.urlsafe_encode64(digest, padding: false)}"
  end
end
