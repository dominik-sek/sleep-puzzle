import { Controller } from "@hotwired/stimulus";

// The article form's editor: a Polish/English tab switcher and a collapsible live
// preview, so the owner writes with the full width and opens the preview on
// demand - the same shape as the content-blocks editor, without its page/iframe
// machinery (the article preview posts the form and swaps the returned HTML).
export default class extends Controller {
    static targets = ["form", "workspace", "preview", "previewButton", "previewButtonLabel",
                      "languageTab", "localePanel", "content", "status"];
    static values = { url: String, lang: String };

    connect() {
        this.previewOpen = false;
        // Reinforced rather than trusted: a Turbo snapshot may restore the
        // preview open, but a fresh visit starts closed so the editor is full
        // width until the owner asks for the preview.
        this.previewTarget.hidden = true;
        this.workspaceTarget.dataset.previewOpen = "false";
        this.previewButtonTarget.setAttribute("aria-expanded", "false");
    }

    disconnect() {
        this.cancel();
    }

    selectLanguage(event) {
        const language = event.currentTarget.dataset.lang;
        if (language === this.langValue) return;
        this.langValue = language;

        for (const panel of this.localePanelTargets) {
            panel.hidden = panel.dataset.lang !== language;
        }
        for (const tab of this.languageTabTargets) {
            const selected = tab.dataset.lang === language;
            tab.setAttribute("aria-pressed", String(selected));
            tab.classList.toggle("bg-accent", selected);
            tab.classList.toggle("text-ink", selected);
            tab.classList.toggle("text-tan", !selected);
        }
        this.schedule();
    }

    togglePreview() {
        if (this.previewOpen) this.closePreview();
        else this.openPreview();
    }

    openPreview() {
        this.previewOpen = true;
        this.previewTarget.hidden = false;
        this.workspaceTarget.dataset.previewOpen = "true";
        this.previewButtonTarget.setAttribute("aria-expanded", "true");
        this.previewButtonLabelTarget.textContent = "Zamknij podgląd";
        this.schedule();
    }

    closePreview() {
        this.previewOpen = false;
        this.previewTarget.hidden = true;
        this.workspaceTarget.dataset.previewOpen = "false";
        this.previewButtonTarget.setAttribute("aria-expanded", "false");
        this.previewButtonLabelTarget.textContent = "Podgląd";
        this.cancel();
        this.previewButtonTarget.focus();
    }

    schedule(event) {
        if (!this.previewOpen) return;
        if (event && !this.formTarget.contains(event.target)) return;
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
        body.set("preview_locale", this.langValue);
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
