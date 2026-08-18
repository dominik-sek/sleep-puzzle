class AddUserToBookings < ActiveRecord::Migration[8.1]
  def up
    add_reference :bookings, :user, foreign_key: true

    # bookings predating the sign-in requirement were keyed only by email
    execute <<~SQL
      UPDATE bookings
      SET user_id = users.id
      FROM users
      WHERE users.email = bookings.email
    SQL

    change_column_null :bookings, :user_id, false
  end

  def down
    remove_reference :bookings, :user, foreign_key: true
  end
end
