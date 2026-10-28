import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["track", "controls", "previous", "next"]

    connect() {
        this.observer = new ResizeObserver(() => this.update())
        this.observer.observe(this.trackTarget)
        this.update()
    }

    disconnect() {
        this.observer.disconnect()
        this.controlsTarget.hidden = true
    }

    previous() { this.scroll(-1) }
    next() { this.scroll(1) }

    scroll(direction) {
        const track = this.trackTarget
        const step = track.firstElementChild.getBoundingClientRect().width + parseFloat(getComputedStyle(track).columnGap)
        track.scrollBy({ left: direction * step, behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth" })
    }

    update() {
        const track = this.trackTarget
        const remaining = track.scrollWidth - track.clientWidth - track.scrollLeft
        this.controlsTarget.hidden = track.scrollWidth <= track.clientWidth + 1
        this.previousTarget.disabled = track.scrollLeft <= 1
        this.nextTarget.disabled = remaining <= 1
        track.classList.toggle("shop-shelf-end", remaining <= 1)
    }
}
