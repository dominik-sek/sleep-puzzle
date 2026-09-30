import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "fallback"]

  connect() {
    // A cached failure can finish before Stimulus attaches the error listener.
    if (this.hasImageTarget && this.imageTarget.complete && this.imageTarget.naturalWidth === 0) {
      this.showFallback()
    }
  }

  showFallback() {
    if (!this.hasImageTarget) return

    this.imageTarget.classList.add("hidden")
    this.fallbackTarget.classList.replace("hidden", "flex")
  }
}
