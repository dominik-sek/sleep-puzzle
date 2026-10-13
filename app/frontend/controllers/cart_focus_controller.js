import { Controller } from "@hotwired/stimulus"

// A cart stream replaces the submitting button along with its confirmation.
// Continue keyboard navigation on the corresponding new button, without moving
// focus for a pointer submission or after the visitor has moved elsewhere.
export default class extends Controller {
    remember(event) {
        const button = event.submitter
        this.button = button === document.activeElement && button?.matches(":focus-visible") ? button : null
    }

    cancel() {
        this.button = null
    }

    cancelOnTab(event) {
        if (event.key === "Tab") this.cancel()
    }

    cancelOnFocus(event) {
        if (event.target !== this.button) this.cancel()
    }

    restore(event) {
        const stream = event.target
        if (!this.button || stream.getAttribute("action") !== "replace" || stream.getAttribute("target") !== this.element.id) return

        const button = this.button
        const regionId = this.element.id
        const render = event.detail.render
        event.detail.render = async (streamElement) => {
            await render(streamElement)
            if (this.button !== button) return
            if (document.activeElement !== document.body && document.activeElement !== button) return

            document.getElementById(regionId)?.querySelector('button[type="submit"]')?.focus({ preventScroll: true })
            this.cancel()
        }
    }
}
