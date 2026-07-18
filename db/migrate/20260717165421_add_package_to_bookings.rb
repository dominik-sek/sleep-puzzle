class AddPackageToBookings < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM bookings WHERE package_id IS NULL"
    change_column_null :bookings, :package_id, false
    add_index :bookings, :package_id
    add_foreign_key :bookings, :packages
  end

  def down
    remove_foreign_key :bookings, :packages
    remove_index :bookings, :package_id
    change_column_null :bookings, :package_id, true
  end
end
