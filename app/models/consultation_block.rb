# == Schema Information
#
# Table name: consultation_blocks
#
#  id         :bigint           not null, primary key
#  all_day    :boolean          default(TRUE), not null
#  category   :string           default("time_off"), not null
#  ends_at    :datetime         not null
#  note       :text
#  starts_at  :datetime         not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_consultation_blocks_on_starts_at_and_ends_at  (starts_at,ends_at)
#
class ConsultationBlock < ApplicationRecord
  CATEGORIES = { "time_off" => "Wolne", "holiday" => "Święto", "external_booking" => "Rezerwacja poza systemem", "other" => "Inne" }.freeze
  validates :starts_at, :ends_at, presence: true
  validates :category, inclusion: { in: CATEGORIES.keys }
  validate :valid_period

  scope :overlapping, ->(from, to) { where("starts_at < ? AND ends_at > ?", to, from) }

  def conflicting_bookings
    return Booking.none unless starts_at && ends_at
    Booking.where(status: [ :pending, :confirmed ]).where("starts_at < ? AND ends_at > ?", ends_at, starts_at).order(:starts_at)
  end

  def category_label
    CATEGORIES.fetch(category, category)
  end

  private

  def valid_period
    errors.add(:ends_at, "musi być później niż początek") if starts_at && ends_at && ends_at <= starts_at
    if all_day? && starts_at && ends_at && (starts_at != starts_at.beginning_of_day || ends_at != ends_at.beginning_of_day)
      errors.add(:base, "Blokada całodniowa musi obejmować pełne dni.")
    end
  end
end
