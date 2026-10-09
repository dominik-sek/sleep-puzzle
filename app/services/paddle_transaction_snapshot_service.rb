require "ostruct"

# Only financial data is retained. Legacy purchases can recover transaction
# lines from Paddle without manufacturing consent or playback evidence.
class PaddleTransactionSnapshotService
  class InvalidTransaction < StandardError; end

  def self.snapshot(value)
    normalize(value).slice("id", "customer_id", "details")
  end

  def self.normalize(value)
    case value
    when Hash then value.to_h.stringify_keys.transform_values { |entry| normalize(entry) }
    when Array then value.map { |entry| normalize(entry) }
    when OpenStruct then normalize(value.to_h)
    else value
    end
  end
  private_class_method :normalize

  def self.map_items!(order)
    lines = order.paddle_transaction_snapshot.dig("details", "line_items") || []
    order.order_items.each do |item|
      next if item.paddle_transaction_item_id.present?

      price_id = item.paddle_price_id || item.product.paddle_price_id
      matches = lines.select { |line| line["price_id"] == price_id }
      # Shared or subsequently changed legacy prices cannot safely identify a
      # product. Leave them visibly unresolved for the owner to investigate.
      siblings = order.order_items.select { |other| (other.paddle_price_id || other.product.paddle_price_id) == price_id }
      next unless matches.one? && siblings.one?

      item.update!(paddle_price_id: price_id, paddle_transaction_item_id: matches.first.fetch("id"))
    end
    unmatched_items = order.order_items.select { |item| item.paddle_transaction_item_id.blank? }
    unmatched_lines = lines.reject { |line| order.order_items.any? { |item| item.paddle_transaction_item_id == line["id"] } }
    if unmatched_items.one? && unmatched_lines.one?
      unmatched_items.first.update!(paddle_price_id: unmatched_lines.first["price_id"],
        paddle_transaction_item_id: unmatched_lines.first.fetch("id"))
    end
  end

  def self.hydrate!(record)
    transaction = snapshot(Paddle::Transaction.retrieve(id: record.paddle_transaction_id))
    payer = Pay::Customer.find_by(processor: :paddle_billing, processor_id: transaction["customer_id"])
    unless transaction["id"] == record.paddle_transaction_id && payer&.owner == record.user
      raise InvalidTransaction, "Paddle transaction does not belong to this purchase"
    end
    record.update!(paddle_transaction_snapshot: transaction)
    map_items!(record) if record.is_a?(Order)
  end
end
