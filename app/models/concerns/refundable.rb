module Refundable
  extend ActiveSupport::Concern

  def refund_adjustments
    return PaddleAdjustment.none if paddle_transaction_id.blank?

    PaddleAdjustment.refunds.where(transaction_id: paddle_transaction_id,
      customer_id: Pay::Customer.where(owner: user, processor: :paddle_billing).select(:processor_id)).order(:created_at)
  end

  def refund_state
    adjustments = refund_adjustments.to_a
    approved = adjustments.select { |adjustment| adjustment.status == "approved" }
    total = paddle_transaction_snapshot.dig("details", "totals", "grand_total").to_i
    return "full" if approved.any?(&:full?) || (total.positive? && approved.sum(&:amount) >= total)
    return "full" if is_a?(Order) && approved.any? && order_items.none? { |item| item.refunded_at.nil? }
    return "partial" if approved.any?
    return "pending_approval" if adjustments.any? { |adjustment| adjustment.status == "pending_approval" }
    return "rejected" if adjustments.any? { |adjustment| adjustment.status == "rejected" }

    "none"
  end

  def refund_label
    I18n.t("refunds.states.#{refund_state}")
  end
end
