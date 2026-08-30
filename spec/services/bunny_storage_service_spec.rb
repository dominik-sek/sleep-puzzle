require 'rails_helper'

RSpec.describe BunnyStorageService do
  # The counterpart of the signing spec: that one pins the read side to Bunny's
  # published test vector, this one pins the write side to what Bunny's storage
  # API actually expects — a PUT to /{zone}/{path} carrying the zone's key.
  def upload(file = audio_upload, kind: "bedtime_story")
    described_class.call(file, kind: kind)
  end

  context "when the storage zone is not configured" do
    it "is not considered configured" do
      expect(described_class).not_to be_configured
    end

    it "refuses the upload and names the missing variables" do
      result = upload

      expect(result).not_to be_stored
      expect(result.error).to include("BUNNY_STORAGE_ZONE", "BUNNY_STORAGE_PASSWORD")
    end

    it "never calls Bunny" do
      expect_any_instance_of(Net::HTTP).not_to receive(:request)

      upload
    end
  end

  context "when the storage zone is configured" do
    before { with_bunny_storage }

    it "PUTs the file into the zone with its access key" do
      captured = nil
      stub_bunny_upload { |request| captured = request }

      result = upload

      expect(result).to be_stored
      expect(captured).to be_a(Net::HTTP::Put)
      expect(captured.path).to eq("/#{BunnyHelpers::STORAGE_ZONE}#{result.path}")
      expect(captured["AccessKey"]).to eq(BunnyHelpers::STORAGE_PASSWORD)
    end

    # Bunny hashes what it received and 400s on a mismatch, so this is what turns
    # a connection dropped near the end into a refusal rather than a stored file
    # that plays as far as it got.
    it "sends a SHA256 checksum of the bytes it streams" do
      captured = nil
      stub_bunny_upload { |request| captured = request }

      upload(audio_upload(content: "ID3 fake audio bytes"))

      expect(captured["Checksum"]).to eq(Digest::SHA256.hexdigest("ID3 fake audio bytes").upcase)
      expect(captured.body_stream.read).to eq("ID3 fake audio bytes")
    end

    # The path is signed exactly as it appears in the URL, so anything needing
    # percent-encoding would be signed in one form and requested in another.
    it "transliterates the filename into something a URL leaves alone" do
      stub_bunny_upload

      path = upload(audio_upload(filename: "Nagranie Śpiącej Sowy.mp3")).path

      expect(path).to match(%r{\A/bajki/nagranie-spiacej-sowy-[0-9a-f]{8}\.mp3\z})
      expect(build_product(cdn_path: path)).to be_valid
    end

    # So the zone reads the way the shop talks about itself, rather than needing
    # the database open alongside Bunny's file browser to tell what is what.
    it "files the recording under the folder for its kind" do
      stub_bunny_upload

      expect(upload(kind: "bedtime_story").path).to start_with("/bajki/")
      expect(upload(kind: "audio_process").path).to start_with("/audioprocesy/")
    end

    # Two products, the same "nagranie.mp3" off the owner's desktop: without the
    # suffix the second upload would silently replace the first product's audio.
    it "gives two uploads of the same filename different paths" do
      stub_bunny_upload

      expect(upload.path).not_to eq(upload.path)
    end

    it "keeps a usable name when the filename transliterates to nothing" do
      stub_bunny_upload

      expect(upload(audio_upload(filename: "🎧.mp3")).path).to match(%r{\A/bajki/audio-[0-9a-f]{8}\.mp3\z})
    end

    describe "what it refuses before touching the network" do
      before { expect_any_instance_of(Net::HTTP).not_to receive(:request) }

      # A guessed folder would file the recording somewhere the owner did not ask
      # for and would have no reason to look.
      it "refuses to guess a folder when no kind has been chosen" do
        result = upload(kind: nil)

        expect(result).not_to be_stored
        expect(result.error).to include("rodzaj produktu")
      end

      it "refuses a file that is not audio" do
        result = upload(audio_upload(filename: "okladka.png"))

        expect(result).not_to be_stored
        expect(result.error).to include("mp3")
      end

      it "refuses a file past the size cap" do
        file = audio_upload
        allow(file.tempfile).to receive(:size).and_return(described_class::MAX_BYTES + 1)

        result = upload(file)

        expect(result).not_to be_stored
        expect(result.error).to include("za duży")
      end

      it "refuses an empty file" do
        result = upload(audio_upload(content: ""))

        expect(result).not_to be_stored
        expect(result.error).to include("pusty")
      end
    end

    it "takes the stored name from an explicitly given filename" do
      stub_bunny_upload
      file = Tempfile.new([ "a1b2c3d4e5", ".bin" ], binmode: true)
      file.write("ID3 fake audio bytes")
      file.flush

      path = described_class.call(file, kind: "bedtime_story", filename: "Kołysanka.mp3").path

      expect(path).to match(%r{\A/bajki/kolysanka-[0-9a-f]{8}\.mp3\z})
    end

    describe "when Bunny refuses" do
      # The two misconfigurations are worth separating: from a bare "upload
      # failed" there is no telling which credential was pasted wrong.
      it "says so when the access key is rejected" do
        stub_bunny_upload(code: 401, body: "unauthorized")

        expect(upload.error).to include("BUNNY_STORAGE_PASSWORD")
      end

      it "says so when the zone is not found" do
        stub_bunny_upload(code: 404, body: "not found")

        expect(upload.error).to include("BUNNY_STORAGE_ZONE")
      end

      it "reports any other refusal with its status" do
        stub_bunny_upload(code: 507, body: "insufficient storage")

        result = upload

        expect(result).not_to be_stored
        expect(result.path).to be_nil
        expect(result.error).to include("507")
      end

      it "marks a server error worth another attempt and a refusal not" do
        stub_bunny_upload(code: 503, body: "unavailable")
        expect(upload).to be_retryable

        stub_bunny_upload(code: 401, body: "unauthorized")
        expect(upload).not_to be_retryable
      end

      it "never marks a file it refused itself as worth retrying" do
        expect(upload(kind: nil)).not_to be_retryable
      end
    end

    it "reports a connection that never got there as something to retry" do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Errno::ECONNRESET)

      result = upload

      expect(result).not_to be_stored
      expect(result.error).to include("Spróbuj ponownie")
      expect(result).to be_retryable
    end
  end

  describe ".rejection" do
    def rejection(file = audio_upload, kind: "bedtime_story")
      described_class.rejection(file, kind: kind)
    end

    context "with the storage zone configured" do
      before do
        with_bunny_storage
        expect_any_instance_of(Net::HTTP).not_to receive(:request)
      end

      it "passes a file there is nothing wrong with" do
        expect(rejection).to be_nil
      end

      it "names what is wrong with anything else" do
        expect(rejection(kind: nil)).to include("rodzaj produktu")
        expect(rejection(audio_upload(filename: "okladka.png"))).to include("mp3")
        expect(rejection(audio_upload(content: ""))).to include("pusty")
        expect(rejection(nil)).to include("Nie wybrano pliku")
      end

      it "refuses a file past the size cap" do
        file = audio_upload
        allow(file.tempfile).to receive(:size).and_return(described_class::MAX_BYTES + 1)

        expect(rejection(file)).to include("za duży")
      end
    end

    it "refuses everything when the storage zone is not configured" do
      expect(rejection).to include("BUNNY_STORAGE_ZONE")
    end
  end

  # The same refusals from a name and a byte count, so a direct upload can be
  # judged from its blob without being read back off disk.
  describe ".rejection_for" do
    before { with_bunny_storage }

    def rejection_for(filename: "nagranie.mp3", size: 1.megabyte, kind: "bedtime_story")
      described_class.rejection_for(kind: kind, filename: filename, size: size)
    end

    it "passes a file there is nothing wrong with" do
      expect(rejection_for).to be_nil
    end

    it "names what is wrong with anything else" do
      expect(rejection_for(filename: nil)).to include("Nie wybrano pliku")
      expect(rejection_for(kind: nil)).to include("rodzaj produktu")
      expect(rejection_for(filename: "okladka.png")).to include("mp3")
      expect(rejection_for(size: described_class::MAX_BYTES + 1)).to include("za duży")
      expect(rejection_for(size: 0)).to include("pusty")
    end

    it "agrees with the check the same file gets as an upload" do
      expect(rejection_for(filename: "okladka.png"))
        .to eq(described_class.rejection(audio_upload(filename: "okladka.png"), kind: "bedtime_story"))
    end
  end

  describe ".host" do
    it "falls back to Falkenstein, which is what a zone gets unless told otherwise" do
      expect(described_class.host).to eq("storage.bunnycdn.com")
    end

    # Bunny shows the endpoint as a URL, and that is what gets pasted into .env
    it "takes only the host out of a pasted URL" do
      stub_const("ENV", ENV.to_h.merge("BUNNY_STORAGE_HOST" => "https://ny.storage.bunnycdn.com/"))

      expect(described_class.host).to eq("ny.storage.bunnycdn.com")
    end
  end
end
