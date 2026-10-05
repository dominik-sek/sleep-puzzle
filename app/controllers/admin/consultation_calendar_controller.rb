module Admin
  class ConsultationCalendarController < BaseController
    def show
      @calendar = ConsultationCalendarService.call(date: params[:date].presence || Date.current)
    rescue Date::Error
      redirect_to admin_consultation_calendar_path, alert: "Wybierz poprawną datę."
    end

    def day
      @calendar = ConsultationCalendarService.call(date: params[:date].presence || Date.current)
      render :day, layout: !turbo_frame_request?
    rescue Date::Error
      render plain: "Wybierz poprawną datę.", status: :unprocessable_entity
    end
  end
end
