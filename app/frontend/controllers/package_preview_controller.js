import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["form", "locale", "content", "status"];
    static values = { url: String };

    disconnect() {
        this.cancel();
    }

    schedule(event) {
        if (!this.formTarget.contains(event.target) && event.target !== this.localeTarget) return;
        this.cancel();
        this.statusTarget.textContent = "Aktualizowanie podglądu…";
        this.timer = setTimeout(() => this.refresh(), 250);
    }

    cancel() {
        clearTimeout(this.timer);
        this.request?.abort();
    }

    async refresh() {
        this.cancel();
        const request = new AbortController();
        this.request = request;
        const body = new FormData(this.formTarget);
        // The edit form carries PATCH; this read-only preview always uses POST.
        body.delete("_method");
        body.set("preview_locale", this.localeTarget.value);
        this.statusTarget.textContent = "Aktualizowanie podglądu…";
        this.contentTarget.setAttribute("aria-busy", "true");

        try {
            const response = await fetch(this.urlValue, {
                method: "POST",
                credentials: "same-origin",
                headers: {
                    "Accept": "text/html",
                    "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
                },
                body,
                signal: request.signal
            });
            if (!response.ok || response.redirected) throw new Error("Preview unavailable");
            const html = await response.text();
            if (request.signal.aborted) return;
            this.contentTarget.innerHTML = html;
            this.statusTarget.textContent = "Podgląd aktualny";
        } catch (error) {
            if (error.name !== "AbortError") {
                this.statusTarget.textContent = "Nie udało się odświeżyć podglądu. Spróbuj ponownie.";
            }
        } finally {
            if (this.request === request) this.contentTarget.removeAttribute("aria-busy");
        }
    }
}
