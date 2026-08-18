# The audio a buyer plays lives on a Bunny pull zone, and whether it can be
# offered at all depends on two environment variables. The suite must not depend
# on whether the machine running it happens to have real ones in .env, so the
# credentials are stubbed away by default and specs that care about the player
# switch them on explicitly.
#
# Unconfigured is the meaningful default: Product#streamable? is false, and the
# dashboard renders the library exactly as it did before the CDN existed — which
# is also what a developer without the credentials sees.
module BunnyHelpers
  # Bunny's own test-vector key, so a spec that hardcodes a signature is checking
  # against the same one its published implementations do.
  TOKEN = "SecurityKey"
  HOST = "token-tester.b-cdn.net"

  STORAGE_ZONE = "sleep-puzzle-audio"
  STORAGE_PASSWORD = "storage-password"
  STORAGE_HOST = "storage.bunnycdn.com"

  # Stubs the readers rather than ENV: how the two variables are parsed is the
  # service spec's business, and every other spec only cares that a key exists.
  def with_bunny_cdn(token: TOKEN, host: HOST)
    allow(BunnySignedUrlService).to receive(:token).and_return(token)
    allow(BunnySignedUrlService).to receive(:host).and_return(host)
  end

  # The write side, switched on the same way and for the same reason: whether the
  # admin form offers an uploader at all depends on these being set.
  def with_bunny_storage(zone: STORAGE_ZONE, password: STORAGE_PASSWORD, host: STORAGE_HOST)
    allow(BunnyStorageService).to receive_messages(zone: zone, password: password, host: host)
  end

  # Answers the one PUT the upload makes, and hands the caller the request so a
  # spec can assert on what was actually sent to Bunny.
  def stub_bunny_upload(code: 201, body: '{"HttpCode":201,"Message":"File uploaded."}', &captured)
    response = instance_double(Net::HTTPResponse, code: code.to_s, body: body)

    allow_any_instance_of(Net::HTTP).to receive(:request) do |_http, request|
      captured&.call(request)
      response
    end
  end

  # A real file on disk, because the service streams what it is given and computes
  # a checksum over it — a double would only prove the doubles agree.
  #
  # Rack::Test's upload rather than ActionDispatch's, because that is the one a
  # request spec knows how to encode into a multipart body; an ActionDispatch
  # upload arrives at the controller as its own to_s.
  def audio_upload(filename: "Nagranie Śpiącej Sowy.mp3", content: "ID3 fake audio bytes")
    file = Tempfile.new([ "upload", File.extname(filename) ], binmode: true)
    file.write(content)
    file.flush

    Rack::Test::UploadedFile.new(file.path, "audio/mpeg", true, original_filename: filename)
  end
end

RSpec.configure do |config|
  config.include BunnyHelpers

  config.before do
    allow(BunnySignedUrlService).to receive_messages(token: nil, host: nil)
    allow(BunnyStorageService).to receive_messages(zone: nil, password: nil)
  end
end
