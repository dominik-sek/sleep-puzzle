# One product in an order, with how many of it were bought.
#
# The product is referenced rather than copied: these are digital goods the owner
# edits in the panel, and the buyer's library has to follow those edits — a
# renamed audio process is the same audio process. Nothing here snapshots the
# price for the same reason Order does not (Paddle owns the money).
# == Schema Information
#
# Table name: order_items
#
#  id         :bigint           not null, primary key
#  quantity   :integer          default(1), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  order_id   :bigint           not null
#  product_id :bigint           not null
#
# Indexes
#
#  index_order_items_on_order_id                 (order_id)
#  index_order_items_on_order_id_and_product_id  (order_id,product_id) UNIQUE
#  index_order_items_on_product_id               (product_id)
#
# Foreign Keys
#
#  fk_rails_...  (order_id => orders.id)
#  fk_rails_...  (product_id => products.id)
#
class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :product_id, uniqueness: { scope: :order_id }
end
