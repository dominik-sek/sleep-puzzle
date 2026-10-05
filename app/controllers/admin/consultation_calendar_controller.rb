module Admin
  class ConsultationCalendarController < BaseController
    def show
      @settings = ConsultationSetting.current
      @date = Date.iso8601(params[:date].presence || Date.current.iso8601)
      @month = @date.beginning_of_month
      @grid_dates = @month.beginning_of_week..@month.end_of_month.end_of_week
      @slots = SlotComparatorService.new(from: @grid_dates.first, to: @grid_dates.last, settings: @settings, public_window: false).schedule_blocks.group_by { |slot| slot.begin.to_date }
      @blocks = ConsultationBlock.overlapping(@grid_dates.first.beginning_of_day, (@grid_dates.last + 1).beginning_of_day).order(:starts_at)
      @bookings = Booking.where(status: [ :pending, :confirmed ]).where("starts_at < ? AND ends_at > ?", (@grid_dates.last + 1).beginning_of_day, @grid_dates.first.beginning_of_day).order(:starts_at)
      @future_blocks = ConsultationBlock.where("ends_at > ?", Time.current).order(:starts_at)
      @extra_slots = ConsultationSlot.where("starts_at > ?", Time.current).order(:starts_at)
    rescue Date::Error
      redirect_to admin_consultation_calendar_path, alert: "Wybierz poprawną datę."
    end
  end
end
