class CreateOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      # restrict_with_error on the association: a product that has been bought
      # cannot be deleted, or the buyer's library loses what it points at
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1

      t.timestamps
    end

    # one row per product in an order; quantity carries the rest
    add_index :order_items, [ :order_id, :product_id ], unique: true
  end
end
