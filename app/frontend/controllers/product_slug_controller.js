import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["regenerate", "expected", "pending", "path", "controls", "generate", "reset", "status"];
    static values = { url: String, currentSlug: String };

    connect() {
        this.form = this.element.closest("form");
        this.onInput = event => {
            if (["record-name-pl", "record-name-en", "record-kind"].includes(event.target.id)) {
                this.clear("Nazwa lub rodzaj zostały zmienione. Wygeneruj podgląd ponownie, aby zmienić adres.");
            }
        };
        this.onSubmit = event => {
            if (!this.request) return;
            event.preventDefault();
            this.statusTarget.textContent = "Poczekaj na podgląd adresu przed zapisaniem.";
        };
        this.form.addEventListener("input", this.onInput);
        this.form.addEventListener("change", this.onInput);
        this.form.addEventListener("submit", this.onSubmit);
        this.controlsTarget.hidden = false;
    }

    disconnect() {
        this.request?.abort();
        this.form.removeEventListener("input", this.onInput);
        this.form.removeEventListener("change", this.onInput);
        this.form.removeEventListener("submit", this.onSubmit);
    }

    async generate() {
        this.clear("");
        const request = new AbortController();
        this.request = request;
        this.generateTarget.disabled = true;
        this.element.setAttribute("aria-busy", "true");
        this.statusTarget.textContent = "Generowanie podglądu adresu…";
        const field = id => this.form.querySelector(`#${id}`).value;

        try {
            const response = await fetch(this.urlValue, {
                method: "POST",
                signal: request.signal,
                headers: {
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                    "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
                },
                body: JSON.stringify({ record: {
                    kind: field("record-kind"),
                    translations: { name: { pl: field("record-name-pl"), en: field("record-name-en") } }
                } })
            });
            if (!response.ok || !response.headers.get("Content-Type")?.includes("application/json")) throw new Error("Preview failed");
            const result = await response.json();
            if (this.request !== request) return;
            if (result.slug === this.currentSlugValue) {
                this.statusTarget.textContent = "Obecny adres już odpowiada tej nazwie.";
                return;
            }
            this.regenerateTarget.value = "1";
            this.expectedTarget.value = result.slug;
            this.pathTarget.textContent = result.path;
            this.pendingTarget.hidden = false;
            this.resetTarget.hidden = false;
            this.statusTarget.textContent = "Podgląd gotowy. Zapisz produkt, aby zmienić adres.";
        } catch (error) {
            if (error.name !== "AbortError" && this.request === request) {
                this.statusTarget.textContent = "Nie udało się wygenerować adresu. Spróbuj ponownie. Możesz też zapisać produkt z obecnym adresem.";
            }
        } finally {
            if (this.request === request) {
                this.request = null;
                this.generateTarget.disabled = false;
                this.element.removeAttribute("aria-busy");
            }
        }
    }

    reset() {
        this.generateTarget.focus();
        this.clear("Obecny adres zostanie zachowany.");
    }

    clear(message) {
        this.request?.abort();
        this.request = null;
        this.generateTarget.disabled = false;
        this.element.removeAttribute("aria-busy");
        this.regenerateTarget.value = "0";
        this.expectedTarget.value = "";
        this.pendingTarget.hidden = true;
        this.resetTarget.hidden = true;
        this.statusTarget.textContent = message;
    }
}
