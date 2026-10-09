class SlotComparatorService < ApplicationService
  SLOT_DURATION = 90.minutes

  def initialize(busy_periods: [], from: nil, to: nil, settings: ConsultationSetting.current, public_window: true, excluding_booking_id: nil)
    @settings = settings
    @from = from || settings.booking_dates.first
    @to = to || settings.booking_dates.last
    @busy_periods = busy_periods
    @public_window = public_window
    @excluding_booking_id = excluding_booking_id
  end

  def call
    busy = @busy_periods + local_busy_periods
    schedule_blocks.reject do |block|
      (@public_window && (block.begin < Time.current + @settings.minimum_notice_hours.hours || !@settings.booking_dates.cover?(block.begin.to_date))) ||
        block.begin <= Time.current || busy.any? { |period| overlap?(block, period) }
    end
  end

  def schedule_blocks
    (weekly_blocks + ConsultationSlot.where(starts_at: @from.beginning_of_day...(@to + 1).beginning_of_day).map { |slot| slot.starts_at...slot.ends_at })
      .uniq { |block| block.begin }.sort_by(&:begin)
  end

  def weekly_blocks
    weekly = @settings.weekly_slots.reject(&:marked_for_destruction?).group_by(&:weekday)
    (@from..@to).flat_map do |date|
      weekly.fetch(date.wday, []).filter_map do |slot|
        starts_at = Time.zone.parse("#{date.iso8601} #{slot.time_of_day}")
        next unless starts_at.strftime("%H:%M") == slot.time_of_day
        starts_at...(starts_at + SLOT_DURATION)
      end
    end
  end

  private

  def local_busy_periods
    from = @from.beginning_of_day
    to = (@to + 2).beginning_of_day
    ConsultationBlock.overlapping(from, to).map { |block| block.starts_at...block.ends_at } +
      Booking.where(status: [ :pending, :confirmed ]).where.not(id: @excluding_booking_id).where("starts_at < ? AND ends_at > ?", to, from).map { |booking| booking.starts_at...booking.ends_at }
  end

  def overlap?(first, second)
    first.begin < second.end && second.begin < first.end
  end
end
