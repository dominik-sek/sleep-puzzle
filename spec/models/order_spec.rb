require 'rails_helper'

# == Schema Information
#
# Table name: orders
#
#  id                    :bigint           not null, primary key
#  paid_at               :datetime
#  status                :integer          default(0), not null
#  token                 :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  paddle_transaction_id :string
#  user_id               :bigint           not null
#
# Indexes
#
#  index_orders_on_paddle_transaction_id  (paddle_transaction_id) UNIQUE
#  index_orders_on_token                  (token) UNIQUE
#  index_orders_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
RSpec.describe Order, type: :model do
  let(:user) { User.create!(email: "customer@example.com", password: "password123") }
  let(:product) { create_product(name: "Bajka o sowie") }

  def create_order(user: self.user, products: [ product ], **attributes)
    user.orders.create!(
      { status: :pending }.merge(attributes),
      &->(order) { products.each { |p| order.order_items.build(product: p) } }
    )
  end

  it "requires at least one line" do
    order = user.orders.build(status: :pending)

    expect(order).not_to be_valid
    expect(order.errors[:order_items]).to be_present
  end

  it "is addressed by token rather than id, because the id reaches Paddle" do
    order = create_order

    expect(order.to_param).to eq(order.token)
    expect(order.token).to be_present
  end

  describe "#paddle_items" do
    # Paddle requires the key; a digital file is only ever bought once per order
    it "gives Paddle one entry per line, always at quantity 1" do
      other = create_product(name: "Audioproces", paddle_price_id: "pri_789")
      order = create_order(products: [ product, other ])

      expect(order.paddle_items).to contain_exactly(
        { priceId: "pri_456", quantity: 1 },
        { priceId: "pri_789", quantity: 1 }
      )
    end
  end

  # the unique index is what enforces it; the validation turns a violation into
  # an error rather than a 500
  it "refuses the same product twice in one order" do
    order = create_order

    duplicate = order.order_items.build(product: product)

    expect(duplicate).not_to be_valid
  end

  describe "#mark_paid!" do
    it "records the transaction and when it was paid" do
      order = create_order

      order.mark_paid!(transaction_id: "txn_1")

      expect(order.reload).to be_paid
      expect(order.paddle_transaction_id).to eq("txn_1")
      expect(order.paid_at).to be_present
    end

    # Pay retries the whole webhook chain when its own charge sync raises, so
    # this runs more than once for one payment
    it "keeps the first confirmation when it runs again" do
      order = create_order
      order.mark_paid!(transaction_id: "txn_1")
      first_paid_at = order.paid_at

      order.mark_paid!(transaction_id: "txn_2")

      expect(order.reload.paid_at).to eq(first_paid_at)
      expect(order.paddle_transaction_id).to eq("txn_1")
    end
  end

  # what the dashboard's audio library will read
  describe "User#purchased_products" do
    it "lists only what has actually been paid for" do
      unpaid = create_product(name: "Nieopłacone", paddle_price_id: "pri_789")
      create_order(products: [ unpaid ])
      create_order.mark_paid!(transaction_id: "txn_1")

      expect(user.purchased_products).to eq([ product ])
    end

    it "lists a product bought twice only once" do
      create_order.mark_paid!(transaction_id: "txn_1")
      create_order.mark_paid!(transaction_id: "txn_2")

      expect(user.purchased_products).to eq([ product ])
    end

    it "does not leak another buyer's purchases" do
      other = User.create!(email: "someone@example.com", password: "password123")
      create_order(user: other).mark_paid!(transaction_id: "txn_1")

      expect(user.purchased_products).to be_empty
    end
  end
end
