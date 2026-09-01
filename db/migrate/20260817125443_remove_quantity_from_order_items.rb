class RemoveQuantityFromOrderItems < ActiveRecord::Migration[8.1]
  def change
    # Everything sold here is a digital file - an MP3 or an MP4 - so a second
    # copy of one is the same copy. An order item is now purely the join between
    # an order and a product, and the unique index on [order_id, product_id] is
    # what keeps it to one.
    remove_column :order_items, :quantity, :integer, null: false, default: 1
  end
end
