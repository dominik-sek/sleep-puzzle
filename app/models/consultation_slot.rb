# == Schema Information
#
# Table name: consultation_slots
#
#  id         :bigint           not null, primary key
#  starts_at  :datetime         not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_consultation_slots_on_starts_at  (starts_at) UNIQUE
#
class ConsultationSlot < ApplicationRecord
  validates :starts_at, presence: true, uniqueness: true
  validate :does_not_overlap

  def ends_at
    starts_at + SlotComparatorService::SLOT_DURATION if starts_at
  end

  private

  def does_not_overlap
    return unless starts_at
    errors.add(:starts_at, "musi być w przyszłości") if starts_at <= Time.current
    other_extras = ConsultationSlot.where.not(id: id).where("starts_at > ? AND starts_at < ?", starts_at - 90.minutes, ends_at)
    weekly = SlotComparatorService.new(from: starts_at.to_date - 1, to: ends_at.to_date).weekly_blocks
    if weekly.any? { |block| starts_at < block.end && block.begin < ends_at } || other_extras.exists?
      errors.add(:starts_at, "nakłada się na inny termin konsultacji")
    end
  end
end
