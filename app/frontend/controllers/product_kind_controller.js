import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["select", "story", "process"];

    connect() { this.update(); }

    update() {
        const process = this.selectTarget.value === "audio_process";
        this.storyTarget.classList.toggle("hidden", process);
        this.processTarget.classList.toggle("hidden", !process);
        this.storyTarget.querySelectorAll("input").forEach(input => { input.disabled = process; });
    }
}
