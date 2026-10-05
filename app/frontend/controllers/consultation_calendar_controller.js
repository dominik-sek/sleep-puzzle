import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["day", "month", "dialog", "dialogFrame", "modeButton", "selectionBar", "selectionCount", "bulkButton", "hint"]
    static values = { dayUrl: String, bulkUrl: String }

    connect() {
        this.selected = new Set()
        this.selecting = false
        this.paintSelection()
    }

    disconnect() {
        document.documentElement.classList.remove("consultation-calendar-modal-open")
    }

    toggleSelectionMode() {
        this.selecting = !this.selecting
        if (!this.selecting) this.clearSelection()
        this.paintSelection()
    }

    clearSelection() {
        this.selected.clear()
        this.rangeAnchor = null
        this.rangeBase = new Set()
        this.paintSelection()
    }

    dayClicked(event) {
        const button = event.currentTarget
        const date = button.dataset.date
        if (this.selecting) {
            event.preventDefault()
            if (event.shiftKey && this.rangeAnchor) {
                this.selected = new Set(this.rangeBase)
                const [first, last] = [date, this.rangeAnchor].sort()
                const cursor = new Date(`${first}T12:00:00Z`)
                while (cursor.toISOString().slice(0, 10) <= last) {
                    const value = cursor.toISOString().slice(0, 10)
                    if (this.rangeSelecting) this.selected.add(value)
                    else this.selected.delete(value)
                    cursor.setUTCDate(cursor.getUTCDate() + 1)
                }
            } else {
                if (this.selected.has(date)) this.selected.delete(date)
                else this.selected.add(date)
                this.rangeAnchor = date
                this.rangeSelecting = this.selected.has(date)
                this.rangeBase = new Set(this.selected)
            }
            this.paintSelection()
            return
        }
        this.open(new URL(this.dayUrlValue, window.location.origin), button, { date })
    }

    openForm(event) {
        if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return
        event.preventDefault()
        this.open(new URL(event.currentTarget.href), event.currentTarget)
    }

    openBulk(event) {
        if (!this.selected.size) return
        const url = new URL(this.bulkUrlValue, window.location.origin)
        Array.from(this.selected).sort().forEach(date => url.searchParams.append("dates[]", date))
        this.open(url, event.currentTarget)
    }

    open(url, trigger, params = {}) {
        this.trigger = trigger
        this.triggerDate = trigger.dataset.date
        Object.entries(params).forEach(([key, value]) => url.searchParams.set(key, value))
        url.searchParams.set("calendar_date", this.monthTarget.dataset.monthDate)
        this.dialogFrameTarget.removeAttribute("src")
        this.dialogFrameTarget.innerHTML = '<p role="status" class="p-5">Wczytywanie…</p>'
        if (!this.dialogTarget.open) this.dialogTarget.showModal()
        document.documentElement.classList.add("consultation-calendar-modal-open")
        this.dialogFrameTarget.src = url.toString()
    }

    dialogLoaded() {
        if (!this.dialogTarget.open) return
        this.dialogFrameTarget.querySelector("h2")?.focus({ preventScroll: true })
    }

    frameMissing(event) {
        event.preventDefault()
        this.frameError()
    }

    frameError() {
        if (!this.dialogTarget.open) return
        this.dialogFrameTarget.innerHTML = '<p role="alert" tabindex="-1" class="p-5">Nie udało się otworzyć danych. Zamknij okno i spróbuj ponownie.</p>'
        this.dialogFrameTarget.querySelector("[role=alert]").focus()
    }

    monthLoaded() {
        this.paintSelection()
        this.element.querySelectorAll('input[name="calendar_date"]').forEach(input => {
            input.value = this.monthTarget.dataset.monthDate
        })
        const url = new URL(window.location.href)
        url.searchParams.set("date", this.monthTarget.dataset.monthDate)
        window.history.replaceState(window.history.state, "", url)
    }

    paintSelection() {
        this.dayTargets.forEach(button => {
            button.toggleAttribute("data-range-anchor", this.selecting && button.dataset.date === this.rangeAnchor)
            button.setAttribute("aria-pressed", String(this.selecting && this.selected.has(button.dataset.date)))
            button.setAttribute("aria-haspopup", this.selecting ? "false" : "dialog")
        })
        this.modeButtonTarget.setAttribute("aria-pressed", String(this.selecting))
        this.modeButtonTarget.textContent = this.selecting ? "Koniec zaznaczania" : "Zaznacz dni"
        this.hintTarget.textContent = this.selecting
            ? "Klikaj dni, aby je zaznaczyć. Shift + kliknięcie zmienia zakres od dnia z przerywaną ramką."
            : "Kliknij dzień, aby zobaczyć szczegóły i dostępne akcje."
        this.selectionBarTarget.hidden = !this.selecting
        this.selectionCountTarget.textContent = `Zaznaczone dni: ${this.selected.size}`
        this.bulkButtonTarget.disabled = this.selected.size === 0
    }

    beforeStream(event) {
        if (event.target.getAttribute("target") !== "consultation_calendar_month") return
        const render = event.detail.render
        event.detail.render = async stream => {
            await render(stream)
            this.selecting = false
            this.clearSelection()
            this.close()
        }
    }

    backdrop(event) {
        if (event.target !== this.dialogTarget) return
        const box = this.dialogTarget.getBoundingClientRect()
        if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) this.close()
    }

    cancel(event) {
        event.preventDefault()
        this.close()
    }

    close() {
        if (this.dialogTarget.open) this.dialogTarget.close()
    }

    closed() {
        document.documentElement.classList.remove("consultation-calendar-modal-open")
        const fallback = this.dayTargets.find(button => button.dataset.date === this.triggerDate)
        const focus = this.trigger?.isConnected ? this.trigger : fallback || this.modeButtonTarget
        focus.focus({ preventScroll: true })
    }

    beforeCache() {
        this.close()
        this.selecting = false
        this.clearSelection()
    }
}
