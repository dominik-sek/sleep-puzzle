class AddRefundsAndBookingChanges < ActiveRecord::Migration[8.1]
  def change
    %i[orders bookings].each do |table|
      add_column table, :consent_accepted_at, :datetime
      add_column table, :legal_snapshot, :jsonb, default: {}, null: false
      add_column table, :legal_confirmation_sent_at, :datetime
      add_column table, :paddle_transaction_snapshot, :jsonb, default: {}, null: false
    end

    add_column :bookings, :canceled_at, :datetime
    add_column :bookings, :settlement_notes, :text
    add_column :bookings, :calendar_sync_pending, :boolean, default: false, null: false

    add_column :order_items, :paddle_price_id, :string
    add_column :order_items, :paddle_transaction_item_id, :string
    add_column :order_items, :first_stream_issued_at, :datetime
    add_column :order_items, :first_played_at, :datetime
    add_column :order_items, :refunded_at, :datetime
    add_index :order_items, :paddle_transaction_item_id, unique: true

    create_table :paddle_adjustments do |t|
      t.string :paddle_id, null: false
      t.string :transaction_id, null: false
      t.string :customer_id, null: false
      t.string :status, null: false
      t.string :action, null: false
      t.datetime :paddle_updated_at, null: false
      t.jsonb :payload, default: {}, null: false
      t.timestamps
    end
    add_index :paddle_adjustments, :paddle_id, unique: true
    add_index :paddle_adjustments, :transaction_id

    create_table :booking_changes do |t|
      t.references :booking, null: false, foreign_key: true
      t.references :admin, null: false, foreign_key: { to_table: :users }
      t.string :kind, null: false
      t.string :initiator, null: false
      t.text :reason, null: false
      t.datetime :received_at, null: false
      t.datetime :previous_starts_at, null: false
      t.datetime :new_starts_at
      t.timestamps
    end
  end
end
