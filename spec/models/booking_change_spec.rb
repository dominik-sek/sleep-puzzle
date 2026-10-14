require "rails_helper"

# == Schema Information
#
# Table name: booking_changes
#
#  id                 :bigint           not null, primary key
#  initiator          :string           not null
#  kind               :string           not null
#  new_starts_at      :datetime
#  previous_starts_at :datetime         not null
#  reason             :text             not null
#  received_at        :datetime         not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  admin_id           :bigint           not null
#  booking_id         :bigint           not null
#
# Indexes
#
#  index_booking_changes_on_admin_id    (admin_id)
#  index_booking_changes_on_booking_id  (booking_id)
#
# Foreign Keys
#
#  fk_rails_...  (admin_id => users.id)
#  fk_rails_...  (booking_id => bookings.id)
#
RSpec.describe BookingChange do
  let(:user) { User.create!(email: "notice-period@example.com", password: "password123") }
  let(:booking) do
    user.bookings.create!(package: create_package, name: "Marta", email: user.email,
      starts_at: 1.month.from_now, legal_snapshot: RefundPolicySnapshot.build(:booking))
  end

  def change(kind, received_at:, starts_at: booking.starts_at)
    described_class.new(booking: booking, kind: kind, received_at: received_at, previous_starts_at: starts_at)
  end

  it "includes the exact 14-day cancellation boundary and excludes later requests" do
    cutoff = booking.starts_at - 14.days
    expect(change("canceled", received_at: cutoff)).to be_timely
    expect(change("canceled", received_at: cutoff + 1.second)).not_to be_timely
    expect(change("canceled", received_at: cutoff).notice_label).to eq("14 dni")
  end

  it "uses calendar days across daylight saving changes" do
    Time.use_zone("Europe/Warsaw") do
      slot = Time.zone.parse("2026-11-05 12:00")
      cutoff = slot - 14.days
      expect((slot - cutoff) / 1.hour).to eq(337)
      expect(change("canceled", received_at: cutoff, starts_at: slot)).to be_timely
      expect(change("canceled", received_at: cutoff + 1.second, starts_at: slot)).not_to be_timely
    end
  end

  it "uses a separate 48-hour rescheduling boundary" do
    cutoff = booking.starts_at - 48.hours
    expect(change("rescheduled", received_at: cutoff)).to be_timely
    expect(change("rescheduled", received_at: cutoff + 1.second)).not_to be_timely
    expect(change("rescheduled", received_at: cutoff).notice_label).to eq("48 godzin")
    expect(change("canceled", received_at: cutoff)).not_to be_timely
  end

  it "keeps the previous 24-hour rule for purchases with an older saved policy" do
    booking.update!(legal_snapshot: { "clauses" => [ { "body" => "Poprzednie zasady: 24 godziny" } ] })
    %w[canceled rescheduled].each do |kind|
      expect(change(kind, received_at: booking.starts_at - 24.hours)).to be_timely
      expect(change(kind, received_at: booking.starts_at - 24.hours + 1.second)).not_to be_timely
      expect(change(kind, received_at: booking.starts_at - 24.hours).notice_label).to eq("24 godziny")
    end
  end

  it "does not apply stricter new rules to legacy purchases without a snapshot" do
    booking.update!(legal_snapshot: {})
    expect(change("canceled", received_at: booking.starts_at - 24.hours)).to be_timely
  end
end
