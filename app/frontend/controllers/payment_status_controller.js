import { Controller } from "@hotwired/stimulus"

// The live node survives Turbo's replacement of the visible payment panel.
// Announce the short outcome, without rereading the receipt or moving focus.
export default class extends Controller {
    static targets = ["panel", "announcement"]

    connect() {
        this.lastMessage = this.message()
        this.observer = new MutationObserver(() => {
            const message = this.message()
            if (!message || message === this.lastMessage) return
            this.lastMessage = message
            this.announcementTarget.textContent = message
        })
        this.observer.observe(this.element, { childList: true, subtree: true })
    }

    disconnect() {
        this.observer.disconnect()
    }

    message() {
        if (!this.hasPanelTarget) return ""
        const heading = this.panelTarget.querySelector("h1")
        return [heading?.textContent, heading?.nextElementSibling?.textContent]
            .filter(Boolean).map((text) => text.trim()).join(" ")
    }
}
