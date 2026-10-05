# == Schema Information
#
# Table name: consultation_settings
#
#  id                    :bigint           not null, primary key
#  booking_window_months :integer          default(2), not null
#  local_availability    :boolean          default(FALSE), not null
#  minimum_notice_hours  :integer          default(24), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
class ConsultationSetting < ApplicationRecord
  DEFAULT_HOURS = { 1 => [ 495 ], 2 => [ 495 ], 3 => [ 495, 1230 ], 4 => [ 495, 870 ], 5 => [ 495, 870 ] }.freeze
  has_many :weekly_slots, class_name: "ConsultationWeeklySlot", dependent: :destroy, inverse_of: :consultation_setting
  accepts_nested_attributes_for :weekly_slots, allow_destroy: true, reject_if: ->(attrs) { attrs["time_of_day"].blank? && attrs["id"].blank? }

  validates :booking_window_months, numericality: { only_integer: true, in: 1..12 }
  validates :minimum_notice_hours, numericality: { only_integer: true, in: 0..720 }
  validate :non_overlapping_weekly_slots
  validate :does_not_overlap_extra_slots

  # Also initializes schema-loaded databases, which don't run migration seed SQL.
  def self.current
    find_by(id: 1) || create_or_find_by!(id: 1) do |setting|
      DEFAULT_HOURS.each do |weekday, minutes|
        minutes.each { |minute| setting.weekly_slots.build(weekday: weekday, minute_of_day: minute) }
      end
    end
  end

  def booking_dates
    Date.current..Date.current.advance(months: booking_window_months)
  end

  private

  def does_not_overlap_extra_slots
    return unless persisted? && weekly_slots.any? { |slot| slot.new_record? || slot.changed? || slot.marked_for_destruction? }

    return unless weekly_slots.all? { |slot| slot.marked_for_destruction? || slot.valid? }

    projected = SlotComparatorService.new(settings: self, from: Date.current, to: Date.current + 1.year).weekly_blocks.sort_by(&:begin)
    if projected.each_cons(2).any? { |first, second| first.end > second.begin }
      errors.add(:base, "Godziny konsultacji nakładają się podczas zmiany czasu. Wybierz inne godziny.")
    end

    ConsultationSlot.where("starts_at > ?", Time.current).find_each do |extra|
      blocks = SlotComparatorService.new(settings: self, from: extra.starts_at.to_date - 1, to: extra.ends_at.to_date).weekly_blocks
      if blocks.any? { |block| extra.starts_at < block.end && block.begin < extra.ends_at }
        errors.add(:base, "Harmonogram nakłada się na dodatkowy termin #{extra.starts_at.strftime('%d.%m.%Y %H:%M')}. Najpierw zmień lub usuń ten termin.")
        break
      end
    end
  end

  def non_overlapping_weekly_slots
    minutes = weekly_slots.reject(&:marked_for_destruction?).filter_map do |slot|
      slot.weekday * 1440 + slot.minute_of_day if slot.weekday&.between?(0, 6) && slot.minute_of_day&.between?(0, 1439)
    end.sort
    return if minutes.empty?

    cyclic = minutes + [ minutes.first + 7 * 1440 ]
    if cyclic.each_cons(2).any? { |first, second| second - first < 90 }
      errors.add(:base, "Godziny konsultacji nie mogą się nakładać (konsultacja trwa 90 minut).")
    end
  end
end
