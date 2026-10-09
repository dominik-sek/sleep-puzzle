# Asks Paddle directly what has happened to the money for a booking.
#
# Needed because booking.paddle_transaction_id is only written when
# transaction.completed arrives: in the gap between the buyer paying and that webhook
# landing, the booking still looks untouched. The browser reporting "I closed the
# overlay" is not enough to justify deleting it, and it can't be trusted to say why it
# closed either - so the transaction is found the same way the webhook finds the
# booking, through custom_data.booking_id on this buyer's Paddle customer.
class BookingPaymentCheckService < ApplicationService
  UNCOMMITTED_STATUSES = %w[draft ready canceled].freeze
  PAID_STATUSES = %w[paid completed].freeze
  UNCOMMITTED_PAYMENT_STATUSES = %w[error canceled dropped action_required].freeze

  LIST_PARAMS = { per_page: 30, order_by: "created_at[DESC]" }.freeze

  def initialize(booking:)
    @booking = booking
  end

  # mirrors BookingCalendarService's idiom: .call sets up, then you ask the questions.
  # One API call answers all of them.
  def call
    self
  end

  # True only when Paddle confirms nothing has been paid.
  #
  # Unknown or in-flight payment states retain the hold without claiming payment.
  def unpaid?
    return false if transactions.nil?

    transactions.all? { |transaction| uncommitted?(transaction) }
  end

  def paid?
    Array(transactions).any? do |transaction|
      PAID_STATUSES.include?(transaction.status) || Array(transaction.payments).any? { |payment| payment.status == "captured" }
    end
  end

  # Whether a card was actually presented and turned down. Paddle keeps every attempt on
  # the transaction, so a decline stays visible even though the transaction itself stays
  # open for the buyer to try again.
  def declined?
    Array(transactions).any? do |transaction|
      Array(transaction.payments).any? { |payment| payment.status == "error" }
    end
  end

  private

  def uncommitted?(transaction)
    UNCOMMITTED_STATUSES.include?(transaction.status) &&
      Array(transaction.payments).all? { |payment| UNCOMMITTED_PAYMENT_STATUSES.include?(payment.status) }
  end

  # nil when Paddle couldn't be asked at all; [] when it simply has nothing for this
  # booking. The two must stay distinguishable - see #unpaid?.
  def transactions
    return @transactions if defined?(@transactions)

    @transactions = fetch_transactions
  end

  def fetch_transactions
    return nil if customer_id.blank?

    # Paddle's collection does not paginate automatically. A missing transaction
    # on the first page must not be mistaken for proof that nothing was paid.
    params = LIST_PARAMS.merge(customer_id: customer_id, "created_at[GTE]": @booking.created_at.iso8601)
    matches = []
    loop do
      page = Paddle::Transaction.list(**params).to_a
      matches.concat(page.select { |transaction| for_this_booking?(transaction) })
      break if page.size < LIST_PARAMS[:per_page]

      cursor = page.last.id
      raise "Paddle pagination did not advance" if cursor.blank? || cursor == params[:after]
      params[:after] = cursor
    end
    matches
  rescue StandardError => e
    Rails.logger.error("Could not check Paddle for payments against booking #{@booking.id}: #{e.class}: #{e.message}")
    nil
  end

  def for_this_booking?(transaction)
    return false unless transaction.custom_data&.booking_id.to_s == @booking.id.to_s
    token = transaction.custom_data&.booking_token
    return token == @booking.token if token.present?

    # Retain compatibility with checkouts opened before tokens were added.
    transaction.created_at.present? && Time.iso8601(transaction.created_at) >= @booking.created_at - 1.second
  end

  def customer_id
    @customer_id ||= @booking.user.payment_processor&.processor_id
  end
end
