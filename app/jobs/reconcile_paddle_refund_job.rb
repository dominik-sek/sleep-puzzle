class ReconcilePaddleRefundJob < ApplicationJob
  queue_as :default
  retry_on Paddle::Error, Paddle::ErrorGenerator, Faraday::Error,
    wait: :polynomially_longer, attempts: 10

  def perform(transaction_id)
    [ Order, Booking ].each do |model|
      record = model.find_by(paddle_transaction_id: transaction_id)
      next unless record && record.refund_adjustments.approved.exists?

      record.with_lock do
        # Full transaction refunds need no mapping. Partial refunds of products
        # in older orders need their original Paddle transaction lines.
        if !record.refund_adjustments.approved.any?(&:full?) &&
            (record.paddle_transaction_snapshot.blank? || (record.is_a?(Order) && record.order_items.any? { |item| item.paddle_transaction_item_id.blank? }))
          PaddleTransactionSnapshotService.hydrate!(record)
        end
        PaddleRefundService.reconcile!(record)
      end
    end
  end
end
