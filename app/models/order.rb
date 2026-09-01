# A shop purchase: the cart, frozen at the moment checkout opened.
#
# The same shape as Booking - saved as `pending` before the Paddle overlay opens,
# flipped by the paddle_billing.transaction.completed webhook, looked up by token
# because the id ends up in a URL handed to Paddle.
#
# No amounts here, deliberately: Paddle owns the money (see Purchasable), so an
# order records *what* was bought and leaves *what it cost* to be read back from
# Paddle. A total stored here would be a second source of truth that silently
# goes stale the first time a price changes.
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
class Order < ApplicationRecord
  belongs_to :user
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  has_secure_token

  enum :status, { pending: 0, paid: 1, payment_failed: 2, canceled: 3 }

  def self.status_label(status)
    I18n.t("orders.statuses.#{status}", default: status.to_s)
  end

  validates :order_items, presence: true

  scope :recent_first, -> { order(created_at: :desc) }

  # A checkout that was opened and never resolved either way. Paddle reports
  # nothing when the buyer simply closes the tab, so without a sweep these sit
  # pending forever - and a pending order now blocks its products from being
  # bought again, which would turn a walked-away checkout into a file the buyer
  # can never purchase.
  scope :stale, ->(cutoff) { pending.where(paddle_transaction_id: nil).where(created_at: ..cutoff) }

  def to_param
    token
  end

  def status_label
    self.class.status_label(status)
  end

  # What Paddle's Checkout.open wants. Always quantity 1 - Paddle requires the
  # key, and a digital file is only ever bought once per order.
  def paddle_items
    order_items.includes(:product).map do |item|
      { priceId: item.product.paddle_price_id, quantity: 1 }
    end
  end

  # Called from OrderConfirmationService when Paddle reports the transaction paid.
  #
  # Idempotent on purpose: Pay re-runs the whole webhook chain when its own charge
  # sync raises, so this can arrive more than once for one payment. Returning
  # early rather than re-saving also keeps paid_at as the moment of the *first*
  # confirmation.
  def mark_paid!(transaction_id:)
    return true if paid?

    update!(status: :paid, paddle_transaction_id: transaction_id, paid_at: Time.current)
    broadcast_status
    true
  end

  # The other end of the same window. A pending order holds its products out of
  # the shop, the cart and the next checkout, so something has to let go of them
  # when the money never arrives - see FailPendingOrderJob and
  # ReleaseAbandonedOrdersJob for who decides that and when.
  def fail_payment!(status)
    update!(status: status)
    broadcast_status
  end

  # Paid, or paid and waiting on Paddle to say so. Both mean the buyer has
  # already committed money for these files, which is what keeps them out of a
  # second cart.
  def open?
    pending? || paid?
  end

  private

  # the buyer is sitting on orders#show watching for exactly this
  def broadcast_status
    broadcast_replace_to self, target: "order_status", partial: "orders/status", locals: { order: self }
  end
end
