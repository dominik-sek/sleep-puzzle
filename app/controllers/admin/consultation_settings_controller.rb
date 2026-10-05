module Admin
  class ConsultationSettingsController < BaseController
    def edit
      @settings = ConsultationSetting.current
      prepare_rows
    end

    def update
      @settings = ConsultationSetting.current
      saved = @settings.with_lock { @settings.update(settings_params) }
      if saved
        redirect_to admin_consultation_calendar_path, notice: "Zapisano harmonogram i ustawienia. Istniejące rezerwacje pozostają bez zmian."
      else
        prepare_rows
        render :edit, status: :unprocessable_entity
      end
    end

    def activate_local
      @settings = ConsultationSetting.current
      unless params[:blocks_migrated] == "1"
        return redirect_to edit_admin_consultation_settings_path, alert: "Potwierdź przeniesienie blokad z Google."
      end
      @settings.with_lock { @settings.update!(local_availability: true) }
      redirect_to admin_consultation_calendar_path, notice: "Dostępnością zarządza teraz aplikacja. Google pozostaje kopią rezerwacji."
    end

    private

    def settings_params
      params.require(:consultation_setting).permit(:booking_window_months, :minimum_notice_hours,
        weekly_slots_attributes: [ :id, :weekday, :time_of_day, :_destroy ])
    end

    def prepare_rows
      # One empty row per day; further rows can be added without JavaScript.
      @rows = (1..7).flat_map do |day|
        weekday = day % 7
        @settings.weekly_slots.reject(&:marked_for_destruction?).select { |slot| slot.weekday == weekday } +
          [ ConsultationWeeklySlot.new(weekday: weekday) ]
      end
    end
  end
end
