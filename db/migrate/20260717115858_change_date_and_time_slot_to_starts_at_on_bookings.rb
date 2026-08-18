class ChangeDateAndTimeSlotToStartsAtOnBookings < ActiveRecord::Migration[8.1]
  def change
    remove_column :bookings, :date, :date
    remove_column :bookings, :time_slot, :date
    add_column :bookings, :starts_at, :datetime
  end
end
