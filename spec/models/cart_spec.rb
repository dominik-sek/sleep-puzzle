require 'rails_helper'

RSpec.describe Cart, type: :model do
  # the real thing is an ActionDispatch session, which is a hash as far as Cart
  # is concerned — including the string keys it hands back
  let(:session) { {} }
  let(:cart) { described_class.from_session(session) }
  let(:product) { create_product(name: "Bajka o sowie") }

  describe "#add" do
    it "puts a product in and counts it" do
      cart.add(product)

      expect(cart.count).to eq(1)
      expect(cart.lines.map(&:product)).to eq([ product ])
    end

    it "adds to the quantity already there rather than replacing it" do
      cart.add(product, quantity: 2)
      cart.add(product)

      expect(cart.count).to eq(3)
      expect(cart.lines.size).to eq(1)
    end

    it "clamps at MAX_QUANTITY so the session cookie cannot be filled past its limit" do
      cart.add(product, quantity: described_class::MAX_QUANTITY + 50)

      expect(cart.count).to eq(described_class::MAX_QUANTITY)
    end
  end

  describe "#set_quantity" do
    it "replaces the quantity" do
      cart.add(product, quantity: 3)
      cart.set_quantity(product, 1)

      expect(cart.count).to eq(1)
    end

    # what the number input produces when the buyer clears it
    it "drops the line when set to zero" do
      cart.add(product)
      cart.set_quantity(product, 0)

      expect(cart).to be_empty
    end
  end

  describe "#remove and #clear" do
    it "removes one line" do
      other = create_product(name: "Audioproces")
      cart.add(product)
      cart.add(other)

      cart.remove(product)

      expect(cart.lines.map(&:product)).to eq([ other ])
    end

    it "empties the cart" do
      cart.add(product)

      cart.clear

      expect(cart).to be_empty
      expect(cart.count).to eq(0)
    end
  end

  # the session survives sign-in, and comes back from the cookie with string keys
  describe "reading an existing session" do
    it "reads quantities stored as strings" do
      session["cart"] = { product.id.to_s => "2" }

      expect(cart.count).to eq(2)
    end

    it "ignores junk rather than raising" do
      session["cart"] = { "0" => "3", product.id.to_s => "-1" }

      expect(cart).to be_empty
    end
  end

  # resolved on read, so nothing has to reach into everyone's session when the
  # owner changes the catalogue
  describe "products that stop being buyable" do
    it "drops a product that has been unpublished" do
      cart.add(product)
      product.update!(published: false)

      expect(described_class.from_session(session)).to be_empty
    end

    it "drops a product that has been deleted" do
      cart.add(product)
      product.destroy!

      expect(described_class.from_session(session)).to be_empty
    end
  end

  describe "#total_label" do
    before do
      allow(PaddlePriceCatalogService).to receive(:call)
        .and_return([ paddle_price(id: "pri_456", amount: "2500", currency: "PLN") ])
    end

    it "multiplies each line by its quantity" do
      cart.add(product, quantity: 3)

      expect(cart.total_label).to eq("75,00 PLN")
    end

    # a total that silently omits a line is worse than no total, since it is the
    # number the buyer checks before paying
    it "is nil when a line has no price" do
      allow(PaddlePriceCatalogService).to receive(:call).and_return([])
      cart.add(product)

      expect(cart.total_label).to be_nil
    end
  end
end
