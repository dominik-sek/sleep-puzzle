import { Controller } from "@hotwired/stimulus"

let activePlayer = null

export default class extends Controller {
  static targets = ["player", "recovery"]

  connect() {
    this.stop = this.stop.bind(this)
    document.addEventListener("turbo:before-visit", this.stop)
    document.addEventListener("turbo:before-cache", this.stop)
    window.addEventListener("pagehide", this.stop)
  }

  disconnect() {
    this.stop()
    document.removeEventListener("turbo:before-visit", this.stop)
    document.removeEventListener("turbo:before-cache", this.stop)
    window.removeEventListener("pagehide", this.stop)
  }

  starting() {
    if (activePlayer && activePlayer !== this.playerTarget) activePlayer.pause()
    activePlayer = this.playerTarget
  }

  stop() {
    this.playerTarget.pause()
    if (activePlayer === this.playerTarget) activePlayer = null
  }

  failed() {
    this.recoveryTarget.hidden = false
  }

  playing() {
    this.recoveryTarget.hidden = true
  }

  retry() {
    this.playerTarget.load()
    this.playerTarget.play().catch(() => this.failed())
  }
}
