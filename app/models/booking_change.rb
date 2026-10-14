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
class BookingChange < ApplicationRecord
  NOTICE_PERIODS = {
    "canceled" => { "amount" => 14, "unit" => "days" },
    "rescheduled" => { "amount" => 48, "unit" => "hours" }
  }.freeze
  LEGACY_NOTICE_PERIOD = { "amount" => 24, "unit" => "hours" }.freeze

  belongs_to :booking
  belongs_to :admin, class_name: "User"

  validates :kind, inclusion: { in: %w[canceled rescheduled] }
  validates :initiator, inclusion: { in: %w[customer owner] }
  validates :reason, :received_at, :previous_starts_at, presence: true
  validate :received_in_past

  def timely?
    received_at <= previous_starts_at - notice_duration
  end

  def notice_period
    # Purchases made before notice periods were saved used the 24-hour rule.
    # Do not reinterpret their cancellation history under the new stricter rule.
    booking.legal_snapshot.dig("booking_notice_periods", kind) || LEGACY_NOTICE_PERIOD
  end

  def notice_label
    I18n.t("refunds.notice.#{notice_period.fetch('unit')}", count: notice_period.fetch("amount"), locale: :pl)
  end

  private

  def notice_duration
    amount = notice_period.fetch("amount")
    notice_period.fetch("unit") == "days" ? amount.days : amount.hours
  end

  def received_in_past
    errors.add(:received_at, "nie może być w przyszłości") if received_at && received_at > Time.current
  end
end
