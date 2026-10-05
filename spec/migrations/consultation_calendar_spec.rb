require "rails_helper"
require Rails.root.join("db/migrate/20261005120000_create_consultation_calendar")

RSpec.describe CreateConsultationCalendar, type: :model do
  it "backfills existing bookings and seeds the previous weekly schedule without changing payment status" do
    user = User.create!(email: "migration-calendar@example.com", password: "password123")
    booking = Booking.create!(user: user, package: create_package, name: "Marta", email: user.email,
      starts_at: Time.zone.parse("2026-10-12 08:15"), status: :confirmed)
    migrate = described_class.new
    suppress_messages do
      migrate.down
      migrate.up
    end
    ActiveRecord::Base.connection.schema_cache.clear!
    Booking.reset_column_information
    expect(booking.reload.ends_at).to eq(booking.starts_at + 90.minutes)
    expect(booking).to be_confirmed
    settings = ConsultationSetting.current
    expect(settings.local_availability?).to be false
    expect(settings.booking_window_months).to eq(2)
    expect(settings.minimum_notice_hours).to eq(24)
    expect(settings.weekly_slots.group_by(&:weekday).transform_values { |slots| slots.map(&:minute_of_day) }).to eq(ConsultationSetting::DEFAULT_HOURS)
  ensure
    ActiveRecord::Base.connection.schema_cache.clear!
    Booking.reset_column_information
  end

  def suppress_messages
    old = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    yield
  ensure
    ActiveRecord::Migration.verbose = old
  end
end
