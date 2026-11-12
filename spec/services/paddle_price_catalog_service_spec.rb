require 'rails_helper'

RSpec.describe PaddlePriceCatalogService do
  include ActiveSupport::Testing::TimeHelpers

  # Real Paddle objects rather than doubles: they are OpenStructs built from the
  # API payload, so a verifying double cannot check them and a plain one would not
  # exercise the nesting the service actually reads.
  def paddle_api_price(id: "pri_1", description: "Jednorazowo", product_name: "Szybka ulga", amount: "24900", currency: "PLN")
    Paddle::Price.new(
      "id" => id,
      "description" => description,
      "product" => product_name && { "name" => product_name },
      "unit_price" => { "amount" => amount, "currency_code" => currency }
    )
  end

  describe ".call" do
    def stub_price_response(status, body, content_type: "text/html")
      connection = Faraday.new(Paddle.config.url) do |conn|
        conn.response :json
        conn.adapter :test do |stub|
          stub.get("/prices") { [ status, { "Content-Type" => content_type }, body ] }
        end
      end
      allow(Paddle::Client).to receive(:connection).and_return(connection)
    end

    it "maps the account's active prices" do
      allow(Paddle::Price).to receive(:list).and_return([ paddle_api_price ])

      price = described_class.call.first

      expect(price.id).to eq("pri_1")
      expect(price.product_name).to eq("Szybka ulga")
      expect(price.label).to eq("Szybka ulga - Jednorazowo - 249,00 PLN")
    end

    it "asks Paddle only for active prices, with the product attached" do
      allow(Paddle::Price).to receive(:list).and_return([])

      described_class.call

      expect(Paddle::Price).to have_received(:list).with(hash_including(status: "active", include: "product"))
    end

    # the admin form still has to render when Paddle is unreachable, falling back
    # to a plain text field for the price id
    it "returns an empty catalogue when the API fails" do
      allow(Paddle::Price).to receive(:list).and_raise(Paddle::Error.new("boom"))
      allow(Rails.logger).to receive(:error)

      expect(described_class.call).to eq([])
      expect(Rails.logger).to have_received(:error).with(/price catalogue/)
    end

    [ 403, 429, 500, 502, 503 ].each do |status|
      it "returns an empty catalogue for an HTML HTTP #{status} response" do
        stub_price_response(status, "<html><title>Access denied</title></html>")
        allow(Rails.logger).to receive(:error)

        expect(described_class.call).to eq([])
        expect(Rails.logger).to have_received(:error).with(/HTTP #{status}/)
      end
    end

    it "still handles structured Paddle API errors" do
      stub_price_response(429, { error: { code: "too_many_requests", detail: "Retry later" } }.to_json,
                          content_type: "application/json")
      allow(Rails.logger).to receive(:error)

      expect(described_class.call).to eq([])
      expect(Rails.logger).to have_received(:error).with(/too_many_requests/)
    end

    it "still maps a successful JSON response through the Paddle client" do
      stub_price_response(200, { data: [ { id: "pri_1", product: { name: "Szybka ulga" },
                                         unit_price: { amount: "24900", currency_code: "PLN" } } ],
                                meta: { pagination: {} } }.to_json, content_type: "application/json")

      expect(described_class.call.first.formatted_amount).to eq("249,00 PLN")
    end

    it "caches a failure for a minute instead of retrying for every catalogue item" do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      allow(Paddle::Price).to receive(:list).and_raise(Faraday::TimeoutError)

      2.times { expect(described_class.call).to eq([]) }
      expect(Paddle::Price).to have_received(:list).once

      travel 61.seconds do
        expect(described_class.call).to eq([])
      end
      expect(Paddle::Price).to have_received(:list).twice
    end

    it "allows a manual refresh to recover before a cached failure expires" do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      allow(Paddle::Price).to receive(:list).and_raise(Faraday::TimeoutError)
      expect(described_class.call).to eq([])

      allow(Paddle::Price).to receive(:list).and_return([ paddle_api_price ])

      expect(described_class.call(refresh: true).first.id).to eq("pri_1")
      expect(described_class.call.first.id).to eq("pri_1")
    end

    it "does not hide unrelated programming errors" do
      allow(Paddle::Price).to receive(:list).and_raise(NoMethodError, "unexpected bug")

      expect { described_class.call }.to raise_error(NoMethodError, "unexpected bug")
    end
  end

  describe ".find" do
    it "returns the matching price" do
      allow(Paddle::Price).to receive(:list).and_return([ paddle_api_price(id: "pri_1") ])

      expect(described_class.find("pri_1").id).to eq("pri_1")
    end

    it "returns nil for an id Paddle no longer lists" do
      allow(Paddle::Price).to receive(:list).and_return([ paddle_api_price(id: "pri_1") ])

      expect(described_class.find("pri_gone")).to be_nil
    end

    it "returns nil without calling Paddle when there is no id" do
      allow(Paddle::Price).to receive(:list)

      expect(described_class.find(nil)).to be_nil
      expect(Paddle::Price).not_to have_received(:list)
    end
  end

  describe "amount formatting" do
    it "keeps the minor units of a two-decimal currency" do
      expect(described_class::Price.new(amount: "24950", currency: "PLN").formatted_amount).to eq("249,50 PLN")
    end

    # dividing by 100 here would show a price a hundred times too small
    it "leaves a currency with no minor unit alone" do
      expect(described_class::Price.new(amount: "1500", currency: "JPY").formatted_amount).to eq("1 500 JPY")
    end

    it "is nil when Paddle sent no amount" do
      expect(described_class::Price.new(id: "pri_1").formatted_amount).to be_nil
    end
  end
end
