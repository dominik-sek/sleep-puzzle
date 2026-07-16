class BookingsController < ApplicationController
  def index
    # mock shape for the 2-month prefetch discussed for the calendar — swap for a real
    # query once we have bookings/business-hours to compute availability from.
    #
    # sparse on purpose: a date not listed here (or with an empty "hours" array) means
    # fully unavailable, so we don't have to enumerate every day/weekend with nothing open.
    @availability = {
      from: "2026-07-16",
      to: "2026-09-16",
      dates: [
        {
          date: "2026-07-17",
          hours: [
            { hour: "12:00", available: true },
            { hour: "12:30", available: true },
            { hour: "13:00", available: false },
            { hour: "14:00", available: true },
            { hour: "14:30", available: false },
            { hour: "15:00", available: false },
            { hour: "15:30", available: false },
            { hour: "15:00", available: false },
            { hour: "15:30", available: false },
            { hour: "15:00", available: false },
            { hour: "15:30", available: false },
            { hour: "15:00", available: false },
            { hour: "15:30", available: false },
          ]
        },
        {
          date: "2026-07-18",
          hours: [
            { hour: "12:00", available: false },
            { hour: "12:30", available: false },
            { hour: "13:00", available: false },
            { hour: "14:00", available: false }
          ]
        },
        {
          date: "2026-07-20",
          hours: [
            { hour: "12:00", available: true },
            { hour: "14:00", available: true }
          ]
        }
      ]
    }

    # get the dates that have at least one available slot
    @available_dates = @availability[:dates].filter_map { |date|
      date[:date] if date[:hours].any? { |hour| hour[:available] }
    }.to_json


  end
end
