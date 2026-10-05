module Admin
  class ConsultationBlocksController < BaseController
    include ConsultationCalendarResponses
    before_action :load_block, only: [ :edit, :update, :destroy ]

    def new
      @block = ConsultationBlock.new(all_day: true, category: "time_off")
      @form_values = { "start_date" => params[:date].presence || Date.current.iso8601,
                       "end_date" => params[:date].presence || Date.current.iso8601 }
      dialog_form(:block)
    end

    def edit
      @form_values = {
        "start_date" => @block.starts_at.to_date.iso8601,
        "end_date" => (@block.all_day? ? @block.ends_at.to_date - 1 : @block.ends_at.to_date).iso8601,
        "start_time" => @block.starts_at.strftime("%H:%M"), "end_time" => @block.ends_at.strftime("%H:%M")
      }
      dialog_form(:block)
    end

    def create
      @block = ConsultationBlock.new
      persist_block(:new)
    end

    def update
      persist_block(:edit)
    end

    def destroy
      ConsultationSetting.current.with_lock { @block.destroy! }
      calendar_changed(date: @block.starts_at.to_date.iso8601, message: "Usunięto blokadę.")
    end

    def new_bulk
      @batch = ConsultationBlockBatch.new(dates: params.permit(dates: []).fetch(:dates, []))
      render :bulk, layout: !turbo_frame_request?
    end

    def bulk
      @batch = ConsultationBlockBatch.new(params.require(:consultation_block_batch).permit(:all_day, :start_time, :end_time, :category, :note, dates: []))
      if @batch.save
        calendar_changed(date: @batch.dates.first, message: "Zapisano blokady dla #{@batch.dates.size} dni.", conflicts: @batch.conflicting_bookings)
      else
        render :bulk, layout: !turbo_frame_request?, status: :unprocessable_entity
      end
    end

    private

    def load_block
      @block = ConsultationBlock.find(params[:id])
    end

    def persist_block(template)
      @form_values = params.require(:consultation_block).permit(:start_date, :end_date, :start_time, :end_time, :all_day, :category, :note).to_h
      saved = ConsultationSetting.current.with_lock do
        @block.assign_attributes(@form_values.slice("all_day", "category", "note"))
        assign_period
        @block.save
      end
      if saved
        calendar_changed(date: @block.starts_at.to_date.iso8601, message: "Zapisano blokadę.", conflicts: @block.conflicting_bookings.to_a)
      else
        if turbo_frame_request?
          render "admin/consultation_calendar/form", locals: { resource: :block }, layout: false, status: :unprocessable_entity
        else
          render template, status: :unprocessable_entity
        end
      end
    end

    def assign_period
      start_date = Date.iso8601(@form_values.fetch("start_date", ""))
      end_date = Date.iso8601(@form_values.fetch("end_date", ""))
      if @block.all_day?
        @block.starts_at = start_date.beginning_of_day
        @block.ends_at = (end_date + 1).beginning_of_day
      else
        @block.starts_at = parse_time(start_date, @form_values["start_time"])
        @block.ends_at = parse_time(end_date, @form_values["end_time"])
      end
    rescue Date::Error, ArgumentError
      @block.starts_at = @block.ends_at = nil
    end

    def parse_time(date, value)
      raise ArgumentError unless value.to_s.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/)
      parsed = Time.zone.parse("#{date.iso8601} #{value}")
      raise ArgumentError unless parsed.strftime("%H:%M") == value
      parsed
    end
  end
end
