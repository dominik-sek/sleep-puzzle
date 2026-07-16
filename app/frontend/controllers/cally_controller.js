import { Controller } from "@hotwired/stimulus"
import dayjs from "dayjs";
export default class extends Controller {
    static targets = ["calendarDate", "calendarMonth", "heading"]

    connect() {
        this.setCalendarDefaults()
    }
    // All dates are expected in ISO-8601 format (YYYY-MM-DD).
    setCalendarDefaults(){
        const now = dayjs();
        let todayFormatted = now.format('YYYY-MM-DD')
        //todo: change the value to actually take the earliest available date from the API instead of simply TODAY
        let twoMonthsFromNow = now.add(2, 'month')
        let twoMonthsFromNowFormatted = twoMonthsFromNow.format('YYYY-MM-DD')

        this.calendarDateTarget.value = todayFormatted // currently selected date
        this.calendarDateTarget.min = todayFormatted // earliest date to be selected
        this.calendarDateTarget.max = twoMonthsFromNowFormatted // latest ^
        // don't set locale — leaving it unset makes cally fall back to the browser locale
        // format-weekday="short" is set as a static HTML attribute on <calendar-date>
    }

}
