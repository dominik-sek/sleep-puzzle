class SlotComparatorService < ApplicationService
  WEEKLY_SCHEDULE = {
    1 => [["08:15", "09:45"]],                    # Mon
    2 => [["08:15", "09:45"]],                    # Tue
    3 => [["08:15", "09:45"], ["20:30", "22:00"]], # Wed (+ evening)
    4 => [["08:15", "09:45"], ["14:30", "16:00"]], # Thu
    5 => [["08:15", "09:45"], ["14:30", "16:00"]], # Fri
  }.freeze

  SCHEDULE_LENGTH = 2.months
  SLOT_DURATION = 1.5.hours

  def initialize(busy_periods:)
    @busy_periods = busy_periods
  end

  def call
    schedule_blocks.reject { |block| busy?(block) }
  end

  private

  def schedule_blocks
    schedule_dates.flat_map do |date|
      WEEKLY_SCHEDULE.fetch(date.wday, []).map do |starts_at, ends_at|
        Time.zone.parse("#{date} #{starts_at}")...Time.zone.parse("#{date} #{ends_at}")
      end
    end
  end

  def schedule_dates
    Date.current..SCHEDULE_LENGTH.from_now.to_date
  end

  def busy?(block)
    @busy_periods.any? { |busy| block.begin < busy.end && busy.begin < block.end }
  end
end