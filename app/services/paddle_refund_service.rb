class PaddleRefundService < ApplicationService
  def initialize(event:)
    @payload = event.to_h.deep_stringify_keys
  end

  def call
    return unless @payload["action"] == "refund"

    PaddleAdjustment.transaction do
      adjustment = PaddleAdjustment.create_or_find_by!(paddle_id: @payload.fetch("id")) do |row|
        row.assign_attributes(attributes)
        row.events = [ @payload ]
      end
      adjustment.with_lock do
        if attributes[:paddle_updated_at] >= adjustment.paddle_updated_at &&
            (!adjustment.status.in?(%w[approved rejected]) || adjustment.status == attributes[:status])
          adjustment.update!(attributes)
        end
        adjustment.update!(events: adjustment.events + [ @payload ]) unless adjustment.events.include?(@payload)
      end
    end

    [ Order, Booking ].each do |model|
      record = model.find_by(paddle_transaction_id: @payload.fetch("transaction_id"))
      next unless record

      record.with_lock { self.class.reconcile!(record) }
    end
    ReconcilePaddleRefundJob.perform_later(@payload.fetch("transaction_id"))
  end

  # Also called on transaction.completed: an adjustment can arrive before its
  # original transaction. Only the verified payer's adjustments may affect it.
  def self.reconcile!(record)
    customer_ids = Pay::Customer.where(owner: record.user, processor: :paddle_billing).pluck(:processor_id)
    approved = record.refund_adjustments.approved.where(customer_id: customer_ids).to_a
    return unless record.is_a?(Order) && approved.any?

    transaction_total = record.paddle_transaction_snapshot.dig("details", "totals", "grand_total").to_i
    transaction_full = approved.any?(&:full?) || (transaction_total.positive? && approved.sum(&:amount) >= transaction_total)
    record.order_items.each do |item|
      next if item.refunded_at?

      full = transaction_full
      lines = approved.flat_map { |adjustment| adjustment.payload.fetch("items", []) }
        .select { |line| item.paddle_transaction_item_id.present? && line["item_id"] == item.paddle_transaction_item_id }
      original = record.paddle_transaction_snapshot.dig("details", "line_items")&.find { |line| line["id"] == item.paddle_transaction_item_id }
      total = original&.dig("totals", "total").to_i
      full ||= lines.any? { |line| line["type"] == "full" }
      full ||= total.positive? && lines.sum { |line| line.dig("totals", "total").to_i } >= total
      item.update!(refunded_at: Time.current) if full
    end
  end

  private

  def attributes
    {
      transaction_id: @payload.fetch("transaction_id"), customer_id: @payload.fetch("customer_id"),
      action: @payload.fetch("action"), status: @payload.fetch("status"), payload: @payload,
      paddle_updated_at: Time.iso8601(@payload.fetch("updated_at"))
    }
  end
end
