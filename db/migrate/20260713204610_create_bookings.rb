class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings do |t|
      t.string :name
      t.integer :package_id
      t.date :date
      t.date :time_slot
      t.integer :status

      t.timestamps
    end
  end
end
