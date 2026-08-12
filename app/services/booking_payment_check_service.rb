# Asks Paddle directly what has happened to the money for a booking.
#
# Needed because booking.paddle_transaction_id is only written when
# transaction.completed arrives: in the gap between the buyer paying and that webhook
# landing, the booking still looks untouched. The browser reporting "I closed the
# overlay" is not enough to justify deleting it, and it can't be trusted to say why it
# closed either — so the transaction is found the same way the webhook finds the
# booking, through custom_data.booking_id on this buyer's Paddle customer.
class BookingPaymentCheckService < ApplicationService
  # Paddle statuses that mean nobody has committed money: a checkout that was opened
  # (draft), had a card presented and turned down (ready), or was given up on
  # (canceled). Deliberately a safe-list — a status Paddle adds later reads as paid, so
  # it can never become the reason a booking is deleted from under a real payment.
  UNCOMMITTED_STATUSES = %w[draft ready canceled].freeze

  # newest first and one page deep: the transaction in question was opened seconds ago,
  # so it is on the first page however long the buyer's history gets
  LIST_PARAMS = { per_page: 50, order_by: "created_at[DESC]" }.freeze

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
  # Anything that stops us establishing that answers false, deliberately: a wrong
  # "unpaid" deletes a booking somebody paid for, while a wrong "paid" only leaves the
  # slot held until ReleaseAbandonedBookingsJob sweeps it.
  def unpaid?
    return false if transactions.nil?

    transactions.all? { |transaction| uncommitted?(transaction) }
  end

  def paid?
    Array(transactions).any? { |transaction| !uncommitted?(transaction) }
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
    UNCOMMITTED_STATUSES.include?(transaction.status)
  end

  # nil when Paddle couldn't be asked at all; [] when it simply has nothing for this
  # booking. The two must stay distinguishable — see #unpaid?.
  def transactions
    return @transactions if defined?(@transactions)

    @transactions = fetch_transactions
  end

  def fetch_transactions
    return nil if customer_id.blank?

    Paddle::Transaction.list(customer_id: customer_id, **LIST_PARAMS)
                       .select { |transaction| for_this_booking?(transaction) }
  rescue StandardError => e
    Rails.logger.error("Could not check Paddle for payments against booking #{@booking.id}: #{e.class}: #{e.message}")
    nil
  end

  def for_this_booking?(transaction)
    transaction.custom_data&.booking_id.to_s == @booking.id.to_s
  end

  def customer_id
    @customer_id ||= @booking.user.payment_processor&.processor_id
  end
end
