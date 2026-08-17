# The visitor's cart, kept in the session rather than the database.
#
# Not an ApplicationRecord: a cart before checkout is a scratch list, and the
# audience browses before signing in. A table would mean a row per anonymous
# visitor, a sweep job to expire them, and a merge on sign-in — for something the
# buyer can rebuild in three clicks. The session already survives sign-in, so the
# cart carries over on its own.
#
# The session holds only { product_id => quantity }, so an edited or unpublished
# product is resolved fresh on every read and a deleted one simply drops out.
class Cart
  # A guard, not a business rule: the session is a cookie, and an unbounded cart
  # would let one visitor fill it past the 4KB limit and break every later write.
  MAX_QUANTITY = 99

  Line = Struct.new(:product, :quantity, keyword_init: true) do
    def price
      PaddlePriceCatalogService.find(product.paddle_price_id)
    end

    # nil when Paddle can't be reached or no longer knows the id — the view shows
    # the line without a price rather than dropping a product the buyer chose
    def price_label
      price&.formatted_amount
    end

    # What this line comes to: the design puts the unit price and the quantity
    # under the name, and the line's own total on the right.
    def line_total_label
      return if price.nil?

      PaddlePriceCatalogService::Price
        .new(amount: price.amount.to_i * quantity, currency: price.currency)
        .formatted_amount
    end
  end

  def self.from_session(session)
    new(session)
  end

  def initialize(session)
    @session = session
  end

  # Only published products, resolved on read: something unpublished after it was
  # added should stop being buyable, without a job reaching into everyone's session.
  def lines
    @lines ||= begin
      products = Product.published.where(id: quantities.keys).index_by(&:id)

      quantities.filter_map do |product_id, quantity|
        product = products[product_id]
        Line.new(product: product, quantity: quantity) if product
      end
    end
  end

  def add(product, quantity: 1)
    write(product.id, quantities.fetch(product.id, 0) + quantity.to_i)
  end

  def set_quantity(product, quantity)
    write(product.id, quantity.to_i)
  end

  def remove(product)
    write(product.id, 0)
  end

  def clear
    @session.delete(SESSION_KEY)
    reset
  end

  def include?(product)
    quantities.key?(product.id)
  end

  # The badge in the navbar: total items, not distinct products, so adding a
  # second copy of one thing still visibly changes the count.
  def count
    lines.sum(&:quantity)
  end

  def empty?
    lines.none?
  end

  # nil rather than 0 when any line's price is unavailable: a total that silently
  # omits a line is worse than no total, since it is the number the buyer checks.
  def total_label
    amounts = lines.map { |line| [ line.price, line.quantity ] }
    return if amounts.any? { |price, _| price.nil? }

    currencies = amounts.map { |price, _| price.currency }.uniq
    return if currencies.many?

    minor = amounts.sum { |price, quantity| price.amount.to_i * quantity }
    PaddlePriceCatalogService::Price
      .new(amount: minor, currency: currencies.first)
      .formatted_amount
  end

  SESSION_KEY = "cart"
  private_constant :SESSION_KEY

  private

  # Session values come back from the cookie with string keys, so they are
  # normalised once here rather than at every call site.
  def quantities
    @quantities ||= (@session[SESSION_KEY] || {})
      .to_h { |product_id, quantity| [ product_id.to_i, quantity.to_i ] }
      .select { |product_id, quantity| product_id.positive? && quantity.positive? }
  end

  def write(product_id, quantity)
    updated = quantities.merge(product_id => quantity.clamp(0, MAX_QUANTITY))
    updated.delete(product_id) unless updated[product_id]&.positive?

    @session[SESSION_KEY] = updated.transform_keys(&:to_s)
    reset
  end

  def reset
    @quantities = nil
    @lines = nil
    self
  end
end
