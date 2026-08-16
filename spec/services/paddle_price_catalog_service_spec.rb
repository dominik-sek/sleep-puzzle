require 'rails_helper'

RSpec.describe PaddlePriceCatalogService do
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
    it "maps the account's active prices" do
      allow(Paddle::Price).to receive(:list).and_return([ paddle_api_price ])

      price = described_class.call.first

      expect(price.id).to eq("pri_1")
      expect(price.product_name).to eq("Szybka ulga")
      expect(price.label).to eq("Szybka ulga — Jednorazowo — 249,00 PLN")
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
