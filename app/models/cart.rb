# The visitor's cart, kept in the session rather than the database.
#
# Not an ApplicationRecord: a cart before checkout is a scratch list, and the
# audience browses before signing in. A table would mean a row per anonymous
# visitor, a sweep job to expire them, and a merge on sign-in - for something the
# buyer can rebuild in three clicks. The session already survives sign-in, so the
# cart carries over on its own.
#
# A **set of product ids**, with no quantities: everything sold here is a digital
# file, so a second copy of one is the same copy. That is why adding is
# idempotent and why the shop's button is a toggle rather than a counter.
#
# The session holds nothing but the ids, so an edited or unpublished product is
# resolved fresh on every read and a deleted one simply drops out.
class Cart
  # A guard, not a business rule: the session is a cookie, and an unbounded cart
  # would let one visitor fill it past the 4KB limit and break every later write.
  MAX_ITEMS = 99

  Line = Struct.new(:product, keyword_init: true) do
    def price
      PaddlePriceCatalogService.find(product.paddle_price_id)
    end

    # nil when Paddle can't be reached or no longer knows the id - the view shows
    # the line without a price rather than dropping a product the buyer chose
    def price_label
      price&.formatted_amount
    end
  end

  def self.from_session(session, owner: nil)
    new(session, owner: owner)
  end

  # `owner` is the signed-in buyer, or nil while browsing signed out. It is what
  # keeps something already claimed out of the cart: the session survives
  # sign-in, so a file added before signing in can turn out to be one this
  # account already owns - or one it is mid-checkout for - and nothing else would
  # notice before checkout charged for it twice.
  def initialize(session, owner: nil)
    @session = session
    @owner = owner
  end

  def lines
    @lines ||= buyable.map { |product| Line.new(product: product) }
  end

  # In the session, published, and not already claimed - everything the buyer is
  # actually being asked to pay for. `count`, `total_label` and the order all
  # read through this, so a claimed file cannot be counted, totalled or charged.
  def buyable
    @buyable ||= resolved.reject { |product| claimed?(product) }
  end

  # In the session but already paid for. Surfaced rather than silently dropped, so
  # the cart can say where something went instead of appearing to lose it.
  def already_owned
    @already_owned ||= resolved.select { |product| owned?(product) }
  end

  # In the session and mid-checkout on another order. Kept separate from
  # #already_owned because the two need different words: one is in the account
  # now, the other is money that has moved and a file that is not there yet.
  def awaiting
    @awaiting ||= resolved.select { |product| awaiting?(product) }
  end

  def owned?(product)
    @owner.present? && owned_ids.include?(product.id)
  end

  def awaiting?(product)
    @owner.present? && awaiting_ids.include?(product.id)
  end

  # Either kind of claim. This, not #owned?, is what decides whether a line can
  # be charged for.
  def claimed?(product)
    owned?(product) || awaiting?(product)
  end

  # Idempotent: a file is either in the cart or it is not.
  def add(product)
    write(product_ids | [ product.id ])
  end

  def remove(product)
    write(product_ids - [ product.id ])
  end

  def clear
    @session.delete(SESSION_KEY)
    reset
  end

  def include?(product)
    product_ids.include?(product.id)
  end

  def count
    lines.size
  end

  def empty?
    lines.none?
  end

  # nil rather than 0 when any line's price is unavailable: a total that silently
  # omits a line is worse than no total, since it is the number the buyer checks.
  def total_label
    prices = lines.map(&:price)
    return if prices.any?(&:nil?)

    currencies = prices.map(&:currency).uniq
    return if currencies.many?

    PaddlePriceCatalogService::Price
      .new(amount: prices.sum { |price| price.amount.to_i }, currency: currencies.first)
      .formatted_amount
  end

  SESSION_KEY = "cart"
  private_constant :SESSION_KEY

  # Session values come back from the cookie as strings, so they are normalised
  # once here rather than at every call site. Insertion order is kept, so the cart
  # lists what the buyer picked in the order they picked it.
  #
  # Whatever is in there has to be *read*, never trusted to be the shape this
  # version writes. A cookie is a live thing in someone's browser: carts written
  # before quantities were dropped hold `{ id => qty }` rather than `[id]`, and
  # since the navbar badge reads the cart on every single page, one unreadable
  # cookie would 500 the whole site for that visitor until they cleared it. The
  # next write replaces it with the current shape, so this ages out on its own.
  def product_ids
    @product_ids ||= begin
      stored = @session[SESSION_KEY]
      ids = stored.is_a?(Hash) ? stored.keys : Array(stored)

      ids.filter_map { |id| Integer(id, exception: false) }.select(&:positive?).uniq
    end
  end

  private

  # Only published products, resolved on read: something unpublished after it was
  # added should stop being buyable, without a job reaching into everyone's session.
  def resolved
    @resolved ||= begin
      products = Product.published.where(id: product_ids).index_by(&:id)

      product_ids.filter_map { |id| products[id] }
    end
  end

  # One query each, not one per line
  def owned_ids
    @owned_ids ||= claim_ids(:purchased_products)
  end

  def awaiting_ids
    @awaiting_ids ||= claim_ids(:awaiting_products)
  end

  def claim_ids(association)
    return Set.new unless @owner

    @owner.public_send(association).where(id: product_ids).pluck(:id).to_set
  end

  def write(ids)
    @session[SESSION_KEY] = ids.last(MAX_ITEMS).map(&:to_s)
    reset
  end

  def reset
    @product_ids = nil
    @resolved = nil
    @owned_ids = nil
    @awaiting_ids = nil
    @buyable = nil
    @already_owned = nil
    @awaiting = nil
    @lines = nil
    self
  end
end
