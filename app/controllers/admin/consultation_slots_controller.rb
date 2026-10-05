module Admin
  class ConsultationSlotsController < BaseController
    include ConsultationCalendarResponses
    before_action :load_slot, only: [ :edit, :update, :destroy ]

    def new
      @slot = ConsultationSlot.new
      @date = params[:date].presence || Date.current.iso8601
      dialog_form(:slot)
    end

    def edit
      @date = @slot.starts_at.to_date.iso8601
      @hour = @slot.starts_at.strftime("%H:%M")
      dialog_form(:slot)
    end

    def create
      @slot = ConsultationSlot.new
      persist_slot(:new)
    end

    def update
      persist_slot(:edit)
    end

    def destroy
      ConsultationSetting.current.with_lock { @slot.destroy! }
      calendar_changed(date: @slot.starts_at.to_date.iso8601, message: "Usunięto dodatkowy termin. Istniejące rezerwacje pozostają bez zmian.")
    end

    private

    def load_slot
      @slot = ConsultationSlot.find(params[:id])
    end

    def persist_slot(template)
      values = params.require(:consultation_slot).permit(:date, :hour)
      @date, @hour = values.values_at(:date, :hour)
      saved = ConsultationSetting.current.with_lock do
        @slot.starts_at = parsed_start
        @slot.save
      end
      if saved
        calendar_changed(date: @date, message: "Zapisano dodatkowy termin.")
      else
        if turbo_frame_request?
          render "admin/consultation_calendar/form", locals: { resource: :slot }, layout: false, status: :unprocessable_entity
        else
          render template, status: :unprocessable_entity
        end
      end
    end

    def parsed_start
      date = Date.iso8601(@date.to_s)
      return nil unless @hour.to_s.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/)
      parsed = Time.zone.parse("#{date.iso8601} #{@hour}")
      parsed if parsed.strftime("%H:%M") == @hour
    rescue Date::Error, ArgumentError
      nil
    end
  end
end
