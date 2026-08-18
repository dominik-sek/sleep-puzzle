class AddLifecycleColumnsToBookings < ActiveRecord::Migration[8.1]
  # These columns were applied straight to the development database without a
  # migration, so this has to run against both that database and a fresh one.
  # The guards make it a no-op where the column already exists.
  class MigrationBooking < ActiveRecord::Base
    self.table_name = "bookings"
  end

  def up
    add_column :bookings, :token, :string unless column_exists?(:bookings, :token)
    MigrationBooking.reset_column_information
    MigrationBooking.where(token: nil).find_each do |booking|
      booking.update_columns(token: SecureRandom.base58(24))
    end
    change_column_null :bookings, :token, false
    add_index :bookings, :token, unique: true unless index_exists?(:bookings, :token)

    # set together when a transaction.completed webhook confirms the booking;
    # the unique index makes redelivered webhooks idempotent
    add_column :bookings, :confirmed_at, :datetime unless column_exists?(:bookings, :confirmed_at)
    add_column :bookings, :paddle_transaction_id, :string unless column_exists?(:bookings, :paddle_transaction_id)
    add_index :bookings, :paddle_transaction_id, unique: true unless index_exists?(:bookings, :paddle_transaction_id)

    # id of the Google Calendar event held for this slot
    add_column :bookings, :calendar_event_id, :string unless column_exists?(:bookings, :calendar_event_id)

    change_column_default :bookings, :status, 0
    MigrationBooking.where(status: nil).update_all(status: 0)
    change_column_null :bookings, :status, false

    add_index :bookings, [ :starts_at, :status ] unless index_exists?(:bookings, [ :starts_at, :status ])
  end

  def down
    remove_index :bookings, [ :starts_at, :status ]
    change_column_null :bookings, :status, true
    change_column_default :bookings, :status, nil
    remove_column :bookings, :calendar_event_id
    remove_column :bookings, :paddle_transaction_id
    remove_column :bookings, :confirmed_at
    remove_column :bookings, :token
  end
end
