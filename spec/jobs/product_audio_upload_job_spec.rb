require 'rails_helper'

RSpec.describe ProductAudioUploadJob do
  include ActiveJob::TestHelper

  def product_with_staged_audio(**attributes)
    create_product(cdn_path: nil, published: false, **attributes).tap do |product|
      product.audio_upload.attach(
        io: StringIO.new("ID3 fake audio bytes"),
        filename: "Nagranie Śpiącej Sowy.mp3",
        content_type: "audio/mpeg"
      )
    end
  end

  before { with_bunny_storage }

  describe "when Bunny takes the file" do
    it "puts the staged file where the product's kind says it goes" do
      # read inside the stub: blob.open closes the tempfile when it returns
      sent = nil
      stub_bunny_upload { |request| sent = request.body_stream.read }
      product = product_with_staged_audio(kind: :bedtime_story)

      described_class.perform_now(product)

      expect(product.reload.cdn_path).to match(%r{\A/bajki/nagranie-spiacej-sowy-[0-9a-f]{8}\.mp3\z})
      expect(sent).to eq("ID3 fake audio bytes")
    end

    it "keeps the name the owner uploaded rather than the blob's key" do
      stub_bunny_upload
      product = product_with_staged_audio

      described_class.perform_now(product)

      expect(product.reload.cdn_path).to include("nagranie-spiacej-sowy")
    end

    it "drops the staged file once it is on the CDN" do
      stub_bunny_upload
      product = product_with_staged_audio

      described_class.perform_now(product)

      expect(product.reload.audio_upload).not_to be_attached
      expect(ActiveStorage::Blob.count).to eq(0)
    end

    it "sets the path on a product that was published before the file arrived" do
      stub_bunny_upload
      product = product_with_staged_audio
      product.update_column(:published, true)

      described_class.perform_now(product)

      expect(product.reload.cdn_path).to be_present
      expect(Product.published).to include(product)
    end

    it "clears the error left by an earlier attempt" do
      stub_bunny_upload
      product = product_with_staged_audio
      product.update_column(:audio_upload_error, "Bunny odrzucił plik (HTTP 507).")

      described_class.perform_now(product)

      expect(product.reload.audio_upload_error).to be_nil
    end
  end

  describe "when Bunny refuses for good" do
    before { stub_bunny_upload(code: 401, body: "unauthorized") }

    it "does not retry" do
      product = product_with_staged_audio

      perform_enqueued_jobs { described_class.perform_now(product) }

      expect(described_class).not_to have_been_enqueued
    end

    it "leaves the reason on the product for the form to show" do
      product = product_with_staged_audio

      described_class.perform_now(product)

      expect(product.reload.audio_upload_error).to include("BUNNY_STORAGE_PASSWORD")
      expect(product).to be_audio_upload_failed
    end

    it "drops the staged file" do
      product = product_with_staged_audio

      described_class.perform_now(product)

      expect(product.reload.audio_upload).not_to be_attached
    end

    it "leaves the path the product was already serving alone" do
      product = product_with_staged_audio
      product.update_column(:cdn_path, "/bajki/stare-nagranie.mp3")

      described_class.perform_now(product)

      expect(product.reload.cdn_path).to eq("/bajki/stare-nagranie.mp3")
    end
  end

  describe "when Bunny could not be reached" do
    it "retries a dropped connection" do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Errno::ECONNRESET)
      product = product_with_staged_audio

      described_class.perform_now(product)

      expect(described_class).to have_been_enqueued
      expect(product.reload.audio_upload).to be_attached
    end

    it "retries a Bunny that answered with a server error" do
      stub_bunny_upload(code: 503, body: "unavailable")
      product = product_with_staged_audio

      described_class.perform_now(product)

      expect(described_class).to have_been_enqueued
    end

    it "gives up with the reason once the attempts run out" do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Errno::ECONNRESET)
      product = product_with_staged_audio

      perform_enqueued_jobs { described_class.perform_now(product) }

      expect(product.reload.audio_upload_error).to include("Bunny")
      expect(product.audio_upload).not_to be_attached
    end
  end

  # The upload finishes long after the request that started it, so the panel is
  # told over the stream both pages subscribe to.
  describe "what it tells the panel" do
    # the test adapter keeps every broadcast for the life of the process
    before { ActionCable.server.pubsub.clear }

    def broadcasts
      ActionCable.server.pubsub.broadcasts(Product::ADMIN_STREAM)
    end

    def dom_id(product, prefix)
      ActionView::RecordIdentifier.dom_id(product, prefix)
    end

    it "updates the row, the form and pops a toast when the file lands" do
      stub_bunny_upload
      product = product_with_staged_audio(name: "Bajka o sowie")

      described_class.perform_now(product)

      expect(broadcasts.last).to include(
        dom_id(product, :audio_badge),
        dom_id(product, :audio_status),
        "Wgrano plik audio",
        "Bajka o sowie"
      )
    end

    # The badge and the form have to be rendered from the product as it is after
    # the job wrote to it, not as it was handed in.
    it "sends the state the product ended up in, not the one it started with" do
      stub_bunny_upload
      product = product_with_staged_audio

      described_class.perform_now(product)

      expect(broadcasts.last).to include(product.reload.cdn_path)
      expect(broadcasts.last).not_to include("Wgrywanie")
    end

    it "carries the reason as the toast's body when the upload failed" do
      stub_bunny_upload(code: 401, body: "unauthorized")
      product = product_with_staged_audio

      described_class.perform_now(product)

      expect(broadcasts.last).to include("Nie udało się wgrać pliku", "BUNNY_STORAGE_PASSWORD")
    end

    it "says nothing until a retry has actually run out of attempts" do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Errno::ECONNRESET)
      product = product_with_staged_audio

      described_class.perform_now(product)

      expect(broadcasts).to be_empty
    end
  end

  describe "when there is nothing to send" do
    it "does nothing for a product whose file is already gone" do
      expect_any_instance_of(Net::HTTP).not_to receive(:request)

      described_class.perform_now(create_product)
    end

    it "discards itself when the product no longer exists" do
      product = product_with_staged_audio
      job = described_class.new(product)
      product.destroy!

      expect { perform_enqueued_jobs { job.enqueue } }.not_to raise_error
    end
  end
end
