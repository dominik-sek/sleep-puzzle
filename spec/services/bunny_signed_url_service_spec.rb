require 'rails_helper'

RSpec.describe BunnySignedUrlService do
  # Bunny publishes these alongside its own reference implementations, so this is
  # the one assertion that proves the signature is the shape a pull zone will
  # accept. Everything else here is about this app's wrapper around it - a wrong
  # signature shows up as a 403 from someone else's server, which is why it is
  # pinned to a known-good value rather than to whatever this code produces.
  VECTOR_KEY = "SecurityKey"
  VECTOR_HOST = "token-tester.b-cdn.net"
  VECTOR_PATH = "/300kb.jpg"
  VECTOR_EXPIRES = 1598024587
  VECTOR_TOKEN = "HS256-o10JRWlsAItyAsdKS6jJKjabHN4FrFsplDHPV1idcX4"

  # The expiry is part of what is signed, so a spec asserting on a signature has
  # to pin the clock as well as the key.
  def at_vector_time
    allow(Time).to receive(:current).and_return(Time.zone.at(VECTOR_EXPIRES) - 6.hours)
    yield
  end

  describe "the signature" do
    before { with_bunny_cdn(token: VECTOR_KEY, host: VECTOR_HOST) }

    it "matches Bunny's published test vector" do
      url = at_vector_time { described_class.call(VECTOR_PATH) }

      expect(url).to eq("https://#{VECTOR_HOST}#{VECTOR_PATH}?token=#{VECTOR_TOKEN}&expires=#{VECTOR_EXPIRES}")
    end

    it "changes when the path does" do
      first = at_vector_time { described_class.call("/a.mp3") }
      second = at_vector_time { described_class.call("/b.mp3") }

      expect(first).not_to eq(second)
    end

    it "changes when the expiry does" do
      first = at_vector_time { described_class.call(VECTOR_PATH) }
      second = at_vector_time { described_class.call(VECTOR_PATH, expires_in: 12.hours) }

      expect(first).not_to eq(second)
    end

    # a path Bunny would see as different from the one signed is a guaranteed 403
    it "signs a path missing its leading slash as though it had one" do
      with_slash = at_vector_time { described_class.call("/bajki/o-sowie.mp3") }
      without = at_vector_time { described_class.call("bajki/o-sowie.mp3") }

      expect(without).to eq(with_slash)
    end
  end

  describe "the expiry" do
    before { with_bunny_cdn }

    it "defaults to six hours out, so seeking mid-recording cannot 403" do
      url = at_vector_time { described_class.call(VECTOR_PATH) }

      expect(url).to include("expires=#{VECTOR_EXPIRES}")
    end

    it "takes a caller's window" do
      url = at_vector_time { described_class.call(VECTOR_PATH, expires_in: 7.hours) }

      expect(url).to include("expires=#{VECTOR_EXPIRES + 1.hour.to_i}")
    end
  end

  describe "configuration" do
    # the pull zone hostname is shown as a full URL on Bunny's dashboard, which is
    # what tends to get pasted into the environment
    it "reads the host out of a pasted URL, scheme and trailing slash and all" do
      stub_const("ENV", ENV.to_h.merge("BUNNY_CDN_HOST" => "https://sleep-puzzle-audio.b-cdn.net/"))
      allow(described_class).to receive(:host).and_call_original

      expect(described_class.host).to eq("sleep-puzzle-audio.b-cdn.net")
    end

    it "takes a bare hostname unchanged" do
      stub_const("ENV", ENV.to_h.merge("BUNNY_CDN_HOST" => "sleep-puzzle-audio.b-cdn.net"))
      allow(described_class).to receive(:host).and_call_original

      expect(described_class.host).to eq("sleep-puzzle-audio.b-cdn.net")
    end

    it "reads the key straight out of the environment" do
      stub_const("ENV", ENV.to_h.merge("BUNNY_CDN_TOKEN" => "abc123"))
      allow(described_class).to receive(:token).and_call_original

      expect(described_class.token).to eq("abc123")
    end

    it "is configured only with both halves" do
      with_bunny_cdn
      expect(described_class).to be_configured

      with_bunny_cdn(token: nil)
      expect(described_class).not_to be_configured

      with_bunny_cdn(host: nil)
      expect(described_class).not_to be_configured
    end
  end

  # An unsigned URL is a guaranteed 403, so handing one back would turn a missing
  # variable into a player that mysteriously fails instead of a caller that can
  # tell there is nothing to offer.
  describe "when there is nothing to sign" do
    it "returns nil with no credentials" do
      expect(described_class.call(VECTOR_PATH)).to be_nil
    end

    it "returns nil for a product with no file uploaded" do
      with_bunny_cdn

      expect(described_class.call(nil)).to be_nil
      expect(described_class.call("")).to be_nil
    end
  end
end
