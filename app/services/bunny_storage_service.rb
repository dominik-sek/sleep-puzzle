# Puts an audio file into the Bunny storage zone the pull zone sits in front of.
#
# The counterpart to BunnySignedUrlService: that one mints a URL for a path, this
# one is how a path comes to exist. Before it, the owner uploaded through Bunny's
# own dashboard and pasted the resulting path into the admin form — two systems to
# be logged into, and a typo in the paste failed as a 403 the first time a buyer
# pressed play rather than as anything visible at the time.
#
# The upload is proxied through the app rather than sent from the browser straight
# to Bunny, because the storage password is a write key for the whole zone: handing
# it to the page would put it in the HTML of any admin screen and in the network log
# of any machine that has ever opened one. Rack has already buffered the upload to a
# tempfile by the time this runs, so proxying costs a streamed copy, not memory.
class BunnyStorageService < ApplicationService
  # Bunny's storage endpoints are region-specific and the zone's own region is not
  # discoverable from here — a PUT to the wrong one 404s — so it is configuration.
  # This is Falkenstein, which is what a zone gets unless it was told otherwise.
  DEFAULT_HOST = "storage.bunnycdn.com"

  # The zone is laid out the way the shop talks about itself, so Bunny's own file
  # browser is readable without cross-referencing the database.
  #
  # Kept here rather than on Product because it means no caller ever supplies a
  # path segment: everything about where a file lands is decided inside this
  # class, from a kind the enum has already constrained to two values.
  FOLDERS = {
    "audio_process" => "audioprocesy",
    "bedtime_story" => "bajki"
  }.freeze

  # An allow-list rather than a check on the browser's Content-Type: browsers
  # disagree about mp3 (audio/mpeg, audio/mp3, application/octet-stream all show
  # up), and it is the extension that ends up in the signed URL either way.
  ALLOWED_EXTENSIONS = %w[mp3 m4a aac ogg opus wav flac].freeze

  # Roughly a two-hour recording at a generous bitrate. The point is not to police
  # the owner's files but to fail on the obvious mistake — a video, an unrendered
  # project — before it has been pushed across the wire.
  MAX_BYTES = 250.megabytes

  # Generous on read because the response only comes after the whole body has been
  # sent, and a 100 MB upload from a home connection is minutes of that. Tight on
  # open, because a host that will not answer at all should say so quickly.
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 600

  # Anything that means the file never got there, as opposed to Bunny refusing it.
  NETWORK_ERRORS = [ Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EPIPE, SocketError, OpenSSL::SSL::SSLError, IOError ].freeze

  class << self
    # Both halves are required: the zone names the bucket, the password is the only
    # thing that authorises writing to it.
    def configured?
      zone.present? && password.present?
    end

    def zone
      ENV["BUNNY_STORAGE_ZONE"].presence
    end

    # The zone's FTP & API password from Bunny's panel, which is a write key for
    # every file in the zone — not the read-only one, and not the CDN token.
    def password
      ENV["BUNNY_STORAGE_PASSWORD"].presence
    end

    # Same tolerance as BunnySignedUrlService#host: Bunny shows hostnames as URLs,
    # and that is what tends to get pasted into the environment.
    def host
      ENV["BUNNY_STORAGE_HOST"].presence&.sub(%r{\Ahttps?://}i, "")&.delete_suffix("/").presence || DEFAULT_HOST
    end
  end

  # @param upload [ActionDispatch::Http::UploadedFile] the file field's value
  # @param kind [String, Symbol] the product's Product#kind, which decides the folder
  def initialize(upload, kind:)
    @upload = upload
    @kind = kind
  end

  # mirrors BookingPaymentCheckService: .call does the work, then you ask.
  def call
    @stored = store

    self
  end

  def stored?
    @stored == true
  end

  # The path to write to Product#cdn_path — set only on success, so a caller that
  # forgets to check gets nil rather than a path to a file that is not there.
  attr_reader :path

  # Why it failed, in the admin's language, ready to be put on the form. The
  # distinction between "your file is wrong" and "Bunny said no" is the whole
  # value of it: only one of them is fixable by trying a different file.
  attr_reader :error

  private

  def store
    return fail_with("Wgrywanie plików nie jest skonfigurowane (BUNNY_STORAGE_ZONE, BUNNY_STORAGE_PASSWORD).") unless self.class.configured?
    return fail_with("Nie wybrano pliku.") if @upload.blank?
    return fail_with("Najpierw wybierz rodzaj produktu — od niego zależy folder w Bunny.") if folder.blank?
    return fail_with("Dozwolone formaty: #{ALLOWED_EXTENSIONS.join(', ')}.") unless ALLOWED_EXTENSIONS.include?(extension)
    return fail_with("Plik jest za duży (maksymalnie #{MAX_BYTES / 1.megabyte} MB).") if size > MAX_BYTES
    return fail_with("Plik jest pusty.") if size.zero?

    upload_to_bunny
  end

  def fail_with(message)
    @error = message

    false
  end

  def upload_to_bunny
    response = put_file

    if response.code.to_i == 201
      @path = storage_path
      return true
    end

    Rails.logger.error("Bunny storage refused an upload of #{storage_path}: #{response.code} #{response.body}")
    fail_with(refusal_message(response.code.to_i))
  rescue *NETWORK_ERRORS => e
    Rails.logger.error("Bunny storage upload of #{storage_path} could not be completed: #{e.class}: #{e.message}")
    fail_with("Nie udało się połączyć z Bunny. Spróbuj ponownie.")
  end

  # 401 and 404 are the two misconfigurations, and they are worth separating: one
  # is the wrong password, the other the wrong zone or region, and from a bare
  # "upload failed" there is no way to tell which was pasted wrong.
  def refusal_message(code)
    case code
    when 401 then "Bunny odrzucił klucz dostępu (BUNNY_STORAGE_PASSWORD)."
    when 400 then "Plik dotarł uszkodzony. Spróbuj ponownie."
    when 404 then "Bunny nie zna tej strefy (BUNNY_STORAGE_ZONE, BUNNY_STORAGE_HOST)."
    else "Bunny odrzucił plik (HTTP #{code})."
    end
  end

  def put_file
    http = Net::HTTP.new(self.class.host, 443)
    http.use_ssl = true
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    http.request(request)
  end

  def request
    Net::HTTP::Put.new(endpoint_path).tap do |request|
      request["AccessKey"] = self.class.password
      request["Content-Type"] = "application/octet-stream"
      # Bunny hashes what it received and 400s on a mismatch, which turns a
      # connection that dropped near the end into a refusal rather than into a
      # stored file that plays as far as it got.
      request["Checksum"] = checksum
      request.content_length = size
      # streamed rather than read: the tempfile may be a hundred megabytes, and
      # holding that in a string would be held for the length of the upload
      request.body_stream = rewound_io
    end
  end

  # The URL the file is written to. The zone name is a path segment here, unlike
  # on the pull zone side, where it is baked into the hostname.
  def endpoint_path
    "/#{self.class.zone}#{storage_path}"
  end

  # What gets written to Product#cdn_path, so it has to satisfy the same rule the
  # column is validated against: characters that survive a URL untouched, because
  # the pull zone signs the path exactly as it appears in the URL.
  #
  # The original name is kept in recognisable form so the storage zone stays
  # readable from Bunny's own file browser, and the random suffix is what keeps
  # two uploads of "nagranie.mp3" from becoming one file — silently replacing a
  # recording another product is still pointing at.
  def storage_path
    @storage_path ||= "/#{folder}/#{slug}-#{SecureRandom.hex(4)}.#{extension}"
  end

  # nil for a kind that is missing or not one of the two, which is refused above
  # rather than defaulted: a guessed folder would file the recording somewhere the
  # owner did not ask for and would have no reason to look.
  def folder
    @folder ||= FOLDERS[@kind.to_s]
  end

  def slug
    basename = File.basename(filename, ".*").parameterize

    basename.presence || "audio"
  end

  def extension
    @extension ||= File.extname(filename).delete_prefix(".").downcase
  end

  def filename
    @upload.try(:original_filename).to_s
  end

  def size
    @size ||= rewound_io.size
  end

  # An UploadedFile in the request, a plain File in a spec that wants to check
  # what actually goes over the wire.
  def io
    @io ||= @upload.try(:tempfile) || @upload
  end

  def rewound_io
    io.tap(&:rewind)
  end

  # Streamed in chunks for the same reason the body is: the file is not read into
  # a string anywhere in this class.
  def checksum
    digest = Digest::SHA256.new
    stream = rewound_io

    while (chunk = stream.read(1.megabyte))
      digest.update(chunk)
    end

    digest.hexdigest.upcase
  end
end
