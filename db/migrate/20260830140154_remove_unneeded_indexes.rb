class RemoveUnneededIndexes < ActiveRecord::Migration[8.1]
  def change
    remove_index :order_items, name: "index_order_items_on_order_id", column: :order_id
  end
end
