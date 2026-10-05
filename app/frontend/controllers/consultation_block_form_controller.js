import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["allDay", "time"]

    connect() {
        this.updateHours()
    }

    updateHours() {
        this.timeTargets.forEach(input => {
            input.disabled = this.allDayTarget.checked
            input.required = !this.allDayTarget.checked
        })
    }
}
