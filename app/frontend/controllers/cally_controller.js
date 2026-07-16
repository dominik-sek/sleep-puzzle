import { Controller } from "@hotwired/stimulus"
import dayjs from "dayjs";
import "dayjs/locale/pl";

dayjs.locale("pl");

export default class extends Controller {
    static targets = ["calendarDate", "calendarMonth", "heading", "hoursPanel", "availableCount"]
    static values = {
        availableDates: Array,
        noSlotsLabel: String
    }

    connect() {
        this.setCalendarDefaults()
        this.setDisallowedDates()
        this.selectedDate = this.calendarDateTarget.value
        this.selectedTime = null
        this.showHoursFor(this.selectedDate)
        this.updateHeading()
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

    dateChanged(event) {
        this.selectedDate = event.target.value
        this.selectedTime = null
        this.showHoursFor(this.selectedDate)
        this.updateHeading()
    }

    timeSelected(event) {
        this.selectedTime = event.currentTarget.dataset.hour
        this.showForm()
    }

    showHoursFor(date) {
        let label = this.noSlotsLabelValue
        this.hoursPanelTargets.forEach((panel) => {
            const isSelected = panel.dataset.date === date
            panel.hidden = !isSelected
            if (isSelected) label = panel.dataset.availableLabel
        })
        this.availableCountTarget.textContent = label
    }

    updateHeading() {
        const formattedDate = dayjs(this.selectedDate).format('D MMMM YYYY')
        this.headingTarget.textContent = formattedDate
    }

    setDisallowedDates(){
        // ran each time cally renders a date cell, 60 days isnt too hard to render so it should be fine performance wise
        this.calendarDateTarget.isDateDisallowed = (date) => {
            const iso = dayjs(date).format('YYYY-MM-DD')
            return !this.availableDatesValue.includes(iso)
        }
    }
    showForm(){
        throw new Error("NOT IMPLEMENTED YET")
    }
}
