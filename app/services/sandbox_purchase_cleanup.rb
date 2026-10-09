# Maintenance only: preserves the account and catalogue, and verifies every stored
# transaction against the sandbox API before deleting anything locally.
class SandboxPurchaseCleanup
  class UnsafeCleanup < StandardError; end

  def initialize(email:)
    raise UnsafeCleanup, "Podaj EMAIL konkretnego konta." if email.blank?

    @user = User.find_by!(email: email.to_s.strip.downcase)
  end

  def preview
    sandbox_only!
    scopes = record_scopes
    {
      email: @user.email,
      user_id: @user.id,
      counts: scopes.transform_values(&:count),
      bookings: @user.bookings.order(:id).pluck(:id, :status, :starts_at, :calendar_event_id),
      orders: @user.orders.order(:id).pluck(:id, :status, :paddle_transaction_id),
      confirmation: fingerprint(scopes)
    }
  end

  def purge!(confirmation:)
    sandbox_only!
    raise UnsafeCleanup, "Najpierw wykonaj podgląd i przekaż jego CONFIRM." if confirmation.blank?

    ConsultationSetting.current.with_lock do
      @user.with_lock do
        # Protect local payment rows while checking their sandbox origin.
        customers.lock.load
        scopes = record_scopes
        scopes.each_value { |scope| scope.lock.load }
        unless ActiveSupport::SecurityUtils.secure_compare(confirmation.to_s, fingerprint(scopes))
          raise UnsafeCleanup, "Zakres danych zmienił się albo CONFIRM jest niepoprawny. Wykonaj nowy podgląd."
        end
        verify_sandbox_records!(scopes)
        counts = scopes.transform_values(&:count)

        # Do not lose event identifiers on a Google failure. Strict release raises
        # and rolls back database changes; repeated Google deletions are idempotent.
        @user.bookings.where.not(calendar_event_id: [ nil, "" ]).find_each do |booking|
          BookingCalendarService.call(booking: booking, strict: true).release
        end

        scopes.each_value(&:delete_all)
        counts
      end
    end
  end

  private

  def sandbox_only!
    return if Pay::PaddleBilling.environment == "sandbox"

    raise UnsafeCleanup, "Usuwanie testów wymaga konfiguracji Paddle sandbox."
  end

  def customers
    Pay::Customer.where(owner: @user, processor: :paddle_billing)
  end

  # Child rows first. Customers stay so the account retains its Paddle identity.
  # No model destroy callbacks are invoked: this must not refund or cancel money.
  def record_scopes
    customer_ids = customers.pluck(:id)
    processor_ids = customers.pluck(:processor_id).compact_blank
    {
      booking_changes: BookingChange.where(booking_id: @user.bookings.select(:id)),
      order_items: OrderItem.where(order_id: @user.orders.select(:id)),
      paddle_adjustments: PaddleAdjustment.where(customer_id: processor_ids),
      pay_webhooks: Pay::Webhook.where(processor: :paddle_billing)
        .where("event -> 'data' ->> 'customer_id' IN (?)", processor_ids),
      pay_charges: Pay::Charge.where(customer_id: customer_ids),
      pay_payment_methods: Pay::PaymentMethod.where(customer_id: customer_ids),
      bookings: Booking.where(user_id: @user.id),
      orders: Order.where(user_id: @user.id)
    }
  end

  def fingerprint(scopes)
    rows = scopes.transform_values { |scope| scope.order(:id).pluck(:id, :updated_at) }
    Digest::SHA256.hexdigest({ user_id: @user.id, customers: customers.order(:id).pluck(:id, :processor_id), rows: rows }.to_json)
  end

  def verify_sandbox_records!(scopes)
    if Pay::Subscription.where(customer_id: customers.select(:id)).exists?
      raise UnsafeCleanup, "Konto ma subskrypcje. Ten skrypt obsługuje tylko jednorazowe zakupy i konsultacje."
    end

    processor_ids = customers.pluck(:processor_id).compact_blank
    processor_ids.each do |id|
      unless Paddle::Customer.retrieve(id: id).id == id
        raise UnsafeCleanup, "Nie potwierdzono klienta #{id} w sandboxie."
      end
    end
    transaction_ids = @user.bookings.pluck(:paddle_transaction_id) + @user.orders.pluck(:paddle_transaction_id) +
      scopes.fetch(:pay_charges).pluck(:processor_id) + scopes.fetch(:paddle_adjustments).pluck(:transaction_id)
    scopes.fetch(:pay_webhooks).find_each do |webhook|
      data = webhook.event.fetch("data", {})
      transaction_ids << data["id"] if webhook.event_type.start_with?("transaction.")
      transaction_ids << data["transaction_id"]
    end
    transaction_ids.compact_blank.uniq.each do |id|
      transaction = Paddle::Transaction.retrieve(id: id)
      unless transaction.id == id && processor_ids.include?(transaction.customer_id)
        raise UnsafeCleanup, "Transakcja #{id} nie należy do klienta tego konta w sandboxie."
      end
    end
  end
end
