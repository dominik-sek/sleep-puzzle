module Admin
  module ConsultationCalendarResponses
    private

    def dialog_form(resource)
      return unless turbo_frame_request?
      render "admin/consultation_calendar/form", locals: { resource: resource }, layout: false
    end

    def calendar_changed(date:, message:, conflicts: [])
      if turbo_frame_request?
        begin
          @calendar = ConsultationCalendarService.call(date: params[:calendar_date].presence || date)
        rescue Date::Error
          @calendar = ConsultationCalendarService.call
        end
        @message, @conflicts = message, conflicts
        render "admin/consultation_calendar/changed", formats: :turbo_stream
      else
        redirect_to admin_consultation_calendar_path(date: date), notice: message
      end
    end
  end
end
