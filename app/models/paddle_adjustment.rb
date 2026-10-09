# == Schema Information
#
# Table name: paddle_adjustments
#
#  id                :bigint           not null, primary key
#  action            :string           not null
#  events            :jsonb            not null
#  paddle_updated_at :datetime         not null
#  payload           :jsonb            not null
#  status            :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  customer_id       :string           not null
#  paddle_id         :string           not null
#  transaction_id    :string           not null
#
# Indexes
#
#  index_paddle_adjustments_on_paddle_id       (paddle_id) UNIQUE
#  index_paddle_adjustments_on_transaction_id  (transaction_id)
#
class PaddleAdjustment < ApplicationRecord
  validates :paddle_id, :transaction_id, :customer_id, :status, :action, :paddle_updated_at, presence: true

  scope :refunds, -> { where(action: "refund") }
  scope :approved, -> { refunds.where(status: "approved") }

  def full?
    payload["type"] == "full"
  end

  def amount
    payload.dig("totals", "total").to_i
  end

  def formatted_amount
    PaddlePriceCatalogService::Price.new(amount: amount.to_s, currency: payload["currency_code"]).formatted_amount
  end
end
