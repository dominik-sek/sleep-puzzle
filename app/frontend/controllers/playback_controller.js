import { Controller } from "@hotwired/stimulus";

// Evidence of browser-reported playback, never proof that an absence of events
// means the customer did not listen. Samples and trailers do not use this.
export default class extends Controller {
    static values = { url: String };

    async record() {
        if (this.sent || this.sending) return;
        this.sending = true;
        try {
            const response = await fetch(this.urlValue, {
                method: "POST",
                credentials: "same-origin",
                headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" },
            });
            this.sent = response.ok;
        } catch {
            // A later playing event can retry without interrupting the audio.
        } finally {
            this.sending = false;
        }
    }
}
