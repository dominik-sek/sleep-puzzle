class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.string :token, null: false
      t.string :paddle_transaction_id
      t.datetime :paid_at

      t.timestamps
    end

    # the checkout success URL is handed to Paddle, so it must not expose a
    # sequential id - the same reason bookings are looked up by token
    add_index :orders, :token, unique: true
    # written by the webhook; unique so a redelivered event cannot be applied to
    # a second order
    add_index :orders, :paddle_transaction_id, unique: true
  end
end
