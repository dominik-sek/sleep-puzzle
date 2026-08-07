import { Controller } from "@hotwired/stimulus"
import dayjs from "dayjs";
import "dayjs/locale/pl";

dayjs.locale("pl");

export default class extends Controller {
    static targets = ["calendarDate", "calendarMonth", "heading", "monthHeading", "hoursHeader", "emptyState", "hoursPanel", "availableCount", "slotForm", "dateField", "timeField", "bookingFrame"]
    static values = {
        availableDates: Array,
        noSlotsLabel: String
    }

    connect() {
        this.setCalendarDefaults()
        this.setDisallowedDates()
        this.selectedDate = this.calendarDateTarget.value || null
        this.selectedTime = null
        this.showHoursFor(this.selectedDate)
        this.updateHeading()
        this.updateMonthHeading(this.calendarDateTarget.focusedDate || this.selectedDate || this.today)
        this.pristineFormHTML = this.bookingFrameTarget.innerHTML
    }
    // All dates are expected in ISO-8601 format (YYYY-MM-DD).
    setCalendarDefaults(){
        const now = dayjs();
        let todayFormatted = now.format('YYYY-MM-DD')
        //todo: change the value to actually take the earliest available date from the API instead of simply TODAY
        let twoMonthsFromNow = now.add(2, 'month')
        let twoMonthsFromNowFormatted = twoMonthsFromNow.format('YYYY-MM-DD')

        this.today = todayFormatted
        // no day is selected up front — the user picks one, and until then the hours
        // panel shows a prompt instead of today's slots
        this.calendarDateTarget.min = todayFormatted // earliest date to be selected
        this.calendarDateTarget.max = twoMonthsFromNowFormatted // latest ^
        // don't set locale — leaving it unset makes cally fall back to the browser locale
        // format-weekday="short" is set as a static HTML attribute on <calendar-date>
    }

    dateChanged(event) {
        this.selectedDate = event.target.value
        this.selectedTime = null
        this.clearSelectedTimeButton()
        this.showHoursFor(this.selectedDate)
        this.updateHeading()
        this.slotFormTarget.hidden = true
    }

    timeSelected(event) {
        this.clearSelectedTimeButton()
        event.currentTarget.setAttribute("aria-pressed", "true")
        this.selectedTime = event.currentTarget.dataset.hour
        this.showForm()
    }

    clearSelectedTimeButton() {
        this.element.querySelectorAll('[aria-pressed="true"]').forEach((button) => {
            button.removeAttribute("aria-pressed")
        })
    }

    showHoursFor(date) {
        this.emptyStateTarget.hidden = Boolean(date)
        this.hoursHeaderTarget.hidden = !date

        let label = this.noSlotsLabelValue
        this.hoursPanelTargets.forEach((panel) => {
            const isSelected = Boolean(date) && panel.dataset.date === date
            panel.hidden = !isSelected
            if (isSelected) label = panel.dataset.availableLabel
        })
        this.availableCountTarget.textContent = label
    }

    updateHeading() {
        // the whole header is hidden while nothing is selected, so there's nothing to format
        if (!this.selectedDate) return

        this.headingTarget.textContent = dayjs(this.selectedDate).format('D MMMM YYYY')
    }

    // cally fires `focusday` whenever the visible page changes (arrows, keyboard, selection),
    // with the newly focused day as a UTC-midnight Date in event.detail
    monthChanged(event) {
        this.suppressPagingTransition()
        this.updateMonthHeading(event.detail)
    }

    // cally re-renders the day cells one frame after this event, reusing the same
    // buttons — without this they'd animate out of the previous month's styling,
    // flashing every day as available before settling into disallowed
    suppressPagingTransition() {
        this.calendarMonthTargets.forEach((month) => { month.dataset.paging = "" })

        requestAnimationFrame(() => requestAnimationFrame(() => {
            this.calendarMonthTargets.forEach((month) => { delete month.dataset.paging })
        }))
    }

    updateMonthHeading(date) {
        // read the UTC parts so a UTC-midnight Date can't slide into the previous month locally
        const day = date instanceof Date
            ? dayjs(new Date(date.getUTCFullYear(), date.getUTCMonth(), 1))
            : dayjs(date)

        const label = day.format('MMMM YYYY')
        // dayjs' Polish month names are lowercase, but this reads as a title
        this.monthHeadingTarget.textContent = label.charAt(0).toUpperCase() + label.slice(1)
    }

    setDisallowedDates(){
        // ran each time cally renders a date cell, 60 days isnt too hard to render so it should be fine performance wise
        this.calendarDateTarget.isDateDisallowed = (date) => {
            const iso = dayjs(date).format('YYYY-MM-DD')
            // a past date must never render as available, even if it's still in
            // availableDatesValue (min already blocks selection, this keeps the styling in sync)
            return iso < this.today || !this.availableDatesValue.includes(iso)
        }
    }
    showForm(){
        this.resetForm()
        this.dateFieldTarget.value = this.selectedDate
        this.timeFieldTarget.value = this.selectedTime
        this.slotFormTarget.hidden = false
    }

    resetForm() {
        this.bookingFrameTarget.innerHTML = this.pristineFormHTML
    }
}
