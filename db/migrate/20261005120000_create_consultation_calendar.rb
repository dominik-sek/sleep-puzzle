class CreateConsultationCalendar < ActiveRecord::Migration[8.1]
  def up
    create_table :consultation_settings do |t|
      t.integer :booking_window_months, default: 2, null: false
      t.integer :minimum_notice_hours, default: 24, null: false
      t.boolean :local_availability, default: false, null: false
      t.timestamps
    end
    add_check_constraint :consultation_settings, "id = 1", name: "consultation_settings_singleton"
    add_check_constraint :consultation_settings, "booking_window_months BETWEEN 1 AND 12 AND minimum_notice_hours BETWEEN 0 AND 720", name: "consultation_settings_limits"
    create_table :consultation_weekly_slots do |t|
      t.references :consultation_setting, null: false, foreign_key: true
      t.integer :weekday, null: false
      t.integer :minute_of_day, null: false
      t.timestamps
    end
    add_unique_constraint :consultation_weekly_slots, [ :weekday, :minute_of_day ], deferrable: :deferred, name: "unique_consultation_weekly_times"
    add_check_constraint :consultation_weekly_slots, "weekday BETWEEN 0 AND 6 AND minute_of_day BETWEEN 0 AND 1439", name: "weekly_slot_time"
    create_table :consultation_blocks do |t|
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.boolean :all_day, default: true, null: false
      t.string :category, default: "time_off", null: false
      t.text :note
      t.timestamps
    end
    add_index :consultation_blocks, [ :starts_at, :ends_at ]
    add_check_constraint :consultation_blocks, "ends_at > starts_at", name: "consultation_block_period"
    create_table :consultation_slots do |t|
      t.datetime :starts_at, null: false
      t.timestamps
    end
    add_index :consultation_slots, :starts_at, unique: true
    add_column :bookings, :ends_at, :datetime
    execute "UPDATE bookings SET ends_at = starts_at + INTERVAL '90 minutes' WHERE starts_at IS NOT NULL"
    execute "INSERT INTO consultation_settings (id, created_at, updated_at) VALUES (1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
    { 1 => [ 495 ], 2 => [ 495 ], 3 => [ 495, 1230 ], 4 => [ 495, 870 ], 5 => [ 495, 870 ] }.each do |weekday, minutes|
      minutes.each do |minute|
        execute "INSERT INTO consultation_weekly_slots (consultation_setting_id, weekday, minute_of_day, created_at, updated_at) VALUES (1, #{weekday}, #{minute}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
      end
    end
  end

  def down
    remove_column :bookings, :ends_at
    drop_table :consultation_slots
    drop_table :consultation_blocks
    drop_table :consultation_weekly_slots
    drop_table :consultation_settings
  end
end
