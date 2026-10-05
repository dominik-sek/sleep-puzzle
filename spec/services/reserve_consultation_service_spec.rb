require "rails_helper"
require "timeout"

RSpec.describe ReserveConsultationService do
  self.use_transactional_tests = false
  include ActiveSupport::Testing::TimeHelpers

  before do
    travel_to Time.zone.parse("2026-10-05 07:00")
    @settings = ConsultationSetting.current
    @previous_settings = @settings.attributes.slice("local_availability", "minimum_notice_hours")
    @settings.update!(local_availability: true, minimum_notice_hours: 24)
    @user = User.create!(email: "concurrency@example.com", password: "password123")
    @package = create_package
    @starts_at = Time.zone.parse("2026-10-12 08:15")
    @threads = []
  end

  after do
    @release << true if @release
    @threads.each { |thread| thread.join(5) }
    Booking.where(user: @user).delete_all
    ConsultationBlock.where(starts_at: @starts_at).delete_all
    @package.destroy!
    @user.destroy!
    @settings.reload.update!(@previous_settings)
    travel_back
  end

  def new_booking
    Booking.new(user: @user, package: @package, name: "Marta", email: @user.email, starts_at: @starts_at)
  end

  def check_serialized_write
    locked = Queue.new
    @release = Queue.new
    result = Queue.new
    @threads << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        ConsultationSetting.current.with_lock do
          yield
          locked << true
          @release.pop
        end
      end
    end
    Timeout.timeout(5) { locked.pop }
    started = Queue.new
    @threads << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        started << true
        result << described_class.call(booking: new_booking)
      end
    end
    Timeout.timeout(5) { started.pop }
    expect { Timeout.timeout(0.2) { result.pop } }.to raise_error(Timeout::Error)
    @release << true
    expect(Timeout.timeout(5) { result.pop }).to be false
    @threads.each(&:value)
  end

  it "serializes simultaneous reservations and sees the first committed booking" do
    check_serialized_write { expect(described_class.call(booking: new_booking)).to be true }
    expect(Booking.where(user: @user).count).to eq(1)
  end

  it "waits for a simultaneous admin block before validating availability" do
    check_serialized_write do
      ConsultationBlock.create!(starts_at: @starts_at, ends_at: @starts_at + 90.minutes, all_day: false)
    end
    expect(Booking.where(user: @user)).to be_empty
  end
end
