class ConsultationCalendarService < ApplicationService
  attr_reader :date, :month, :grid_dates, :slots, :blocks, :bookings, :future_blocks, :extra_slots, :settings

  def initialize(date: Date.current)
    @date = date.is_a?(Date) ? date : Date.iso8601(date.to_s)
  end

  def call
    @settings = ConsultationSetting.current
    @month = date.beginning_of_month
    @grid_dates = month.beginning_of_week..month.end_of_month.end_of_week
    @slots = SlotComparatorService.new(from: grid_dates.first, to: grid_dates.last, settings: settings, public_window: false).schedule_blocks.group_by { |slot| slot.begin.to_date }
    @blocks = ConsultationBlock.overlapping(grid_dates.first.beginning_of_day, (grid_dates.last + 1).beginning_of_day).order(:starts_at).to_a
    @bookings = Booking.where(status: [ :pending, :confirmed ]).where("starts_at < ? AND ends_at > ?", (grid_dates.last + 1).beginning_of_day, grid_dates.first.beginning_of_day).order(:starts_at).to_a
    @future_blocks = ConsultationBlock.where("ends_at > ?", Time.current).order(:starts_at)
    @extra_slots = ConsultationSlot.where("starts_at > ?", Time.current).order(:starts_at)
    self
  end

  def bookings_on(day)
    bookings.select { |booking| overlaps_day?(booking, day) }
  end

  def blocks_on(day)
    blocks.select { |block| overlaps_day?(block, day) }
  end

  def extras_on(day)
    ConsultationSlot.where(starts_at: day.beginning_of_day...(day + 1).beginning_of_day).order(:starts_at)
  end

  def slot_state(slot)
    booking = bookings.find { |record| slot.begin < record.ends_at && record.starts_at < slot.end }
    return booking.confirmed? ? "Potwierdzona" : "Oczekuje na płatność" if booking
    return "Blokada" if blocks.any? { |record| slot.begin < record.ends_at && record.starts_at < slot.end }
    slot.begin > Time.current ? "Wolny" : "Miniony"
  end

  private

  def overlaps_day?(record, day)
    record.starts_at < (day + 1).beginning_of_day && record.ends_at > day.beginning_of_day
  end
end
