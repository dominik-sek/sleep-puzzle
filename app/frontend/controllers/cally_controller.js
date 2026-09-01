import { Controller } from "@hotwired/stimulus"
import dayjs from "dayjs";
import "dayjs/locale/pl";
import "dayjs/locale/en";

// No locale is chosen at import. This module is evaluated once per full page load,
// so anything decided here survives every Turbo navigation afterwards - which is
// how switching language left the calendar in the language you started in until
// you pressed reload. The locale arrives per connect() instead, as a value the
// server renders onto the element.

export default class extends Controller {
    static targets = ["calendarDate", "calendarMonth", "heading", "monthHeading", "hoursHeader", "emptyState", "hoursPanel", "availableCount", "slotForm", "dateField", "timeField", "bookingFrame", "overlay",
                      "summary", "summaryPackage", "summarySlot", "summaryPrice", "summaryDuration"]
    static values = {
        slotLength: String,
        availableDates: Array,
        noSlotsLabel: String,
        // rendered by the server with the page, so it is right on a Turbo
        // navigation without anything having to be told the language changed
        locale: { type: String, default: "pl" }
    }

    connect() {
        // first, before anything that touches the calendar element: this is the
        // only copy of the buy form and resetForm() writes it back on every slot
        // change, so a throw above it used to blank the form on the first click.
        this.pristineFormHTML = this.bookingFrameTarget.innerHTML
        this.setCalendarDefaults()
        this.setDisallowedDates()
        this.selectedDate = this.calendarDateTarget.value || null
        this.selectedTime = null
        this.showHoursFor(this.selectedDate)
        this.updateHeading()
        this.updateMonthHeading(this.selectedDate || this.initialFocusedDate)
    }
    // All dates are expected in ISO-8601 format (YYYY-MM-DD).
    setCalendarDefaults(){
        const now = dayjs();
        let todayFormatted = now.format('YYYY-MM-DD')
        let twoMonthsFromNow = now.add(2, 'month')
        let twoMonthsFromNowFormatted = twoMonthsFromNow.format('YYYY-MM-DD')

        this.today = todayFormatted
        // no day is selected up front - the user picks one, and until then the hours
        // panel shows a prompt instead of today's slots
        this.calendarDateTarget.min = todayFormatted // earliest date to be selected
        this.calendarDateTarget.max = twoMonthsFromNowFormatted // latest ^

        // Open on the first month that actually has something in it, so the last
        // days of a month don't render as a wall of ghosts with one live day and
        // read as fully booked. focusedDate only moves the view; nothing is
        // selected, so the hours panel still waits for a real choice.
        //
        // It is a String prop ("YYYY-MM-DD") and atomico throws on a type
        // mismatch rather than coercing, so a Date here kills the whole connect().
        this.initialFocusedDate = this.availableDatesValue[0] || this.today
        this.calendarDateTarget.focusedDate = this.initialFocusedDate
        // both the month heading we format ourselves and cally's own month and
        // weekday names, so the widget agrees with the page it is on
        dayjs.locale(this.localeValue)
        this.calendarDateTarget.locale = this.localeValue
        // format-weekday="short" is set as a static HTML attribute on <calendar-date>
    }

    dateChanged(event) {
        this.selectedDate = event.target.value
        this.selectedTime = null
        this.clearSelectedTimeButton()
        this.showHoursFor(this.selectedDate, { reveal: true })
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

    showHoursFor(date, { reveal = false } = {}) {
        this.emptyStateTarget.hidden = Boolean(date)
        this.hoursHeaderTarget.hidden = !date

        let label = this.noSlotsLabelValue
        // the offset comes off the day, not the page: a two-month window can
        // straddle the DST change, so the two halves of it are on different ones
        this.selectedTimezone = null
        this.hoursPanelTargets.forEach((panel) => {
            const isSelected = Boolean(date) && panel.dataset.date === date
            panel.hidden = !isSelected
            if (isSelected) {
                label = panel.dataset.availableLabel
                this.selectedTimezone = panel.dataset.timezone
            }
        })
        this.availableCountTarget.textContent = label

        if (reveal && date) this.revealHours()
    }

    // Below md the hours sit under a full month grid - measured at ~560px, the
    // calendar's bottom is 240px past the fold. Picking a day changed nothing the
    // visitor could see and announced nothing, so the pivot of the whole task read
    // as "the page ignored me". The header is a live region (see _calendar), so
    // moving focus to it also speaks the date and the count.
    revealHours() {
        const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches

        this.hoursHeaderTarget.scrollIntoView({
            block: "nearest",
            behavior: reduced ? "auto" : "smooth"
        })
        this.hoursHeaderTarget.focus({ preventScroll: true })
    }

    updateHeading() {
        // the whole header is hidden while nothing is selected, so there's nothing to format
        if (!this.selectedDate) return

        // .locale() on the instance, not the global set in setCalendarDefaults:
        // the global was not sticking and this rendered "31 August 2026" on the
        // Polish page. The summary formats the same way for the same reason.
        this.headingTarget.textContent = this.formatSlotDate(this.selectedDate)
    }

    // cally fires `focusday` whenever the visible page changes (arrows, keyboard, selection),
    // with the newly focused day as a UTC-midnight Date in event.detail
    monthChanged(event) {
        this.suppressPagingTransition()
        this.updateMonthHeading(event.detail)
    }

    // cally re-renders the day cells one frame after this event, reusing the same
    // buttons - without this they'd animate out of the previous month's styling,
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

        // same instance-locale fix as the hours header: the global dayjs.locale()
        // set in setCalendarDefaults was not sticking, so the month above a
        // Polish calendar rendered in English
        const label = day.locale(this.localeValue).format('MMMM YYYY')
        // dayjs' Polish month names are lowercase and this reads as a title. English
        // ones are already capitalised, so this is a no-op there.
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
        this.bindPackageSelect()
        this.updateSummary()
    }

    // The form is re-rendered from pristine HTML on every slot change, so the
    // listener has to be attached each time rather than once on connect.
    bindPackageSelect() {
        const select = this.packageSelect
        if (!select) return

        select.addEventListener("change", () => this.updateSummary())
    }

    get packageSelect() {
        return this.element.querySelector("select[name='booking[package_id]']")
    }

    // Restates what is being bought at the moment of commitment: the package, the
    // slot already chosen above, and the price. The amount is read from the
    // option's own data-price, which the server formatted - no round trip, and
    // PaddlePriceCatalogService stays the only thing that formats money.
    //
    // A package the catalogue could not price carries no data-price. That is the
    // same signal the server guards on, so the submit is disabled here rather
    // than letting the buyer discover it after a booking row exists.
    updateSummary() {
        if (!this.hasSummaryTarget) return

        const select = this.packageSelect
        const option = select?.selectedOptions?.[0]
        const price = option?.dataset?.price
        const chosen = Boolean(option?.value)

        this.summaryTarget.hidden = !chosen
        if (!chosen) return this.setSubmitDisabled(false)

        this.summaryPackageTarget.textContent = option.textContent.trim()

        // the appointment: a human date, the time, and which clock it is on. The
        // page never stated a timezone, which for an /en visitor booking against
        // a real person's calendar is a missed consultation waiting to happen.
        this.summarySlotTarget.textContent = [
            this.formatSlotDate(this.selectedDate),
            this.selectedTime,
            this.selectedTimezone
        ].filter(Boolean).join(" · ")

        // the package's support window is a different fact from the length of
        // the call, so it gets its own line rather than sitting in the slot
        this.summaryDurationTarget.textContent = [ this.slotLengthValue, option.dataset.duration ]
            .filter(Boolean).join(" · ")

        this.summaryPriceTarget.textContent = price || ""

        // no readable price means nothing can be charged for it
        this.setSubmitDisabled(!price)
    }

    formatSlotDate(iso) {
        if (!iso) return ""

        return dayjs(iso).locale(this.localeValue).format("D MMMM YYYY")
    }

    setSubmitDisabled(disabled) {
        const submit = this.element.querySelector("#booking_form button[type='submit']")
        if (submit) submit.disabled = disabled
    }

    resetForm() {
        // never blank the form over a missing snapshot - an empty buy form at the
        // point of payment is worse than a stale one
        if (typeof this.pristineFormHTML !== "string") return

        this.bookingFrameTarget.innerHTML = this.pristineFormHTML
    }

    // paddle_controller fires paddle:completed once the charge goes through; the browser
    // is then on its way to the confirmation page, and anything clicked in between would
    // start a second booking the buyer never asked for
    lock() {
        this.overlayTarget.hidden = false
        this.element.setAttribute("aria-busy", "true")
    }

    // bfcache can restore this page with the overlay still up when the buyer hits back
    unlock() {
        this.overlayTarget.hidden = true
        this.element.removeAttribute("aria-busy")
    }
}
