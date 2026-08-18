require 'rails_helper'

RSpec.describe Cart, type: :model do
  # the real thing is an ActionDispatch session, which is a hash as far as Cart
  # is concerned — including the strings it hands back
  let(:session) { {} }
  let(:cart) { described_class.from_session(session) }
  let(:product) { create_product(name: "Bajka o sowie") }

  describe "#add" do
    it "puts a product in and counts it" do
      cart.add(product)

      expect(cart.count).to eq(1)
      expect(cart.lines.map(&:product)).to eq([ product ])
    end

    # everything sold is a digital file, so a second copy is the same copy
    it "is idempotent" do
      3.times { cart.add(product) }

      expect(cart.count).to eq(1)
      expect(cart.lines.size).to eq(1)
    end

    it "keeps the order things were picked in" do
      other = create_product(name: "Audioproces")
      cart.add(product)
      cart.add(other)

      expect(cart.lines.map(&:product)).to eq([ product, other ])
    end

    it "caps at MAX_ITEMS so the session cookie cannot be filled past its limit" do
      products = Array.new(described_class::MAX_ITEMS + 5) { create_product }
      products.each { |p| cart.add(p) }

      expect(cart.count).to eq(described_class::MAX_ITEMS)
    end
  end

  describe "#remove and #clear" do
    it "removes one line and leaves the rest" do
      other = create_product(name: "Audioproces")
      cart.add(product)
      cart.add(other)

      cart.remove(product)

      expect(cart.lines.map(&:product)).to eq([ other ])
    end

    it "is quiet about removing something that was never in there" do
      expect { cart.remove(product) }.not_to raise_error
      expect(cart).to be_empty
    end

    it "empties the cart" do
      cart.add(product)

      cart.clear

      expect(cart).to be_empty
      expect(cart.count).to eq(0)
    end
  end

  describe "#include?" do
    it "is what the shop's toggle reads" do
      expect(cart.include?(product)).to be(false)

      cart.add(product)

      expect(cart.include?(product)).to be(true)
    end
  end

  # the session survives sign-in, and comes back from the cookie as strings
  describe "reading an existing session" do
    it "reads ids stored as strings" do
      session["cart"] = [ product.id.to_s ]

      expect(cart.count).to eq(1)
    end

    it "ignores junk rather than raising" do
      session["cart"] = [ "0", "-1", "" ]

      expect(cart).to be_empty
    end

    it "collapses a duplicate left by an older session" do
      session["cart"] = [ product.id.to_s, product.id.to_s ]

      expect(cart.count).to eq(1)
    end

    # A cookie is a live thing in someone's browser. Carts written before
    # quantities were dropped hold { id => qty }, and the navbar badge reads the
    # cart on every page — so an unreadable one would 500 the whole site for that
    # visitor until they cleared it.
    context "written by the version that still had quantities" do
      it "reads the products out of the old { id => quantity } shape" do
        other = create_product(name: "Audioproces")
        session["cart"] = { product.id.to_s => "2", other.id.to_s => "1" }

        expect(cart.lines.map(&:product)).to eq([ product, other ])
        expect(cart.count).to eq(2)
      end

      it "drops the old quantity rather than carrying it over" do
        session["cart"] = { product.id.to_s => "3" }

        expect(cart.count).to eq(1)
      end

      it "replaces it with the current shape on the next write" do
        session["cart"] = { product.id.to_s => "2" }

        cart.add(create_product(name: "Audioproces"))

        expect(session["cart"]).to be_an(Array)
        expect(cart.count).to eq(2)
      end
    end

    it "survives a cookie holding something it has never written" do
      session["cart"] = "nonsense"

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

  # a digital file is bought once and kept, so owning one takes it out of the
  # cart entirely rather than letting checkout charge for it a second time
  describe "when the buyer already owns something in the session" do
    let(:owner) { User.create!(email: "customer@example.com", password: "password123") }
    let(:other) { create_product(name: "Audioproces", paddle_price_id: "pri_789") }
    let(:cart) { described_class.from_session(session, owner: owner) }

    before do
      allow(PaddlePriceCatalogService).to receive(:call)
        .and_return([ paddle_price(id: "pri_456", amount: "2500", currency: "PLN"),
                      paddle_price(id: "pri_789", amount: "12900", currency: "PLN") ])

      order = owner.orders.create!(status: :pending, order_items: [ OrderItem.new(product: product) ])
      order.mark_paid!(transaction_id: "txn_1")

      cart.add(product)
      cart.add(other)
    end

    it "leaves the owned product out of the lines" do
      expect(cart.lines.map(&:product)).to eq([ other ])
      expect(cart.count).to eq(1)
    end

    it "leaves it out of the total" do
      expect(cart.total_label).to eq("129,00 PLN")
    end

    # surfaced rather than silently dropped, so the cart can say where it went
    it "reports it as already owned" do
      expect(cart.already_owned).to eq([ product ])
    end

    it "counts an unpaid order for nothing" do
      owner.orders.create!(status: :pending, order_items: [ OrderItem.new(product: other) ])

      expect(cart.lines.map(&:product)).to eq([ other ])
    end

    it "does not apply to someone browsing signed out" do
      anonymous = described_class.from_session(session)

      expect(anonymous.count).to eq(2)
      expect(anonymous.already_owned).to be_empty
    end

    it "does not apply to a different buyer" do
      stranger = User.create!(email: "someone@example.com", password: "password123")

      expect(described_class.from_session(session, owner: stranger).count).to eq(2)
    end
  end

  describe "#total_label" do
    before do
      allow(PaddlePriceCatalogService).to receive(:call)
        .and_return([ paddle_price(id: "pri_456", amount: "2500", currency: "PLN"),
                      paddle_price(id: "pri_789", amount: "12900", currency: "PLN") ])
    end

    it "adds the lines up" do
      cart.add(product)
      cart.add(create_product(name: "Audioproces", paddle_price_id: "pri_789"))

      expect(cart.total_label).to eq("154,00 PLN")
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
