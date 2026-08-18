class AddEmailToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :email, :string, default: "", null: false
  end
end
