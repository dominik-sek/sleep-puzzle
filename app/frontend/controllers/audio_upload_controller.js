import { Controller } from "@hotwired/stimulus";

const MEGABYTE = 1024 * 1024;

function formatSize(bytes) {
    return `${(bytes / MEGABYTE).toFixed(1)} MB`;
}

// Progress for the admin's audio field. The file goes to the staging service as
// a direct upload before the form is submitted, so @rails/activestorage reports
// real byte progress on the one transfer the owner actually waits through.
//
// The extension and size checks here only save a doomed upload from being sent;
// BunnyStorageService refuses the same things server-side.
export default class extends Controller {
    static targets = ["input", "progress", "bar", "percent", "label", "error", "submit"];
    static values = { maxBytes: Number, extensions: Array };

    validate() {
        const file = this.inputTarget.files[0];
        this.hideError();
        if (!file) return;

        const extension = file.name.split(".").pop().toLowerCase();

        if (!this.extensionsValue.includes(extension)) {
            this.reject(`Dozwolone formaty: ${this.extensionsValue.join(", ")}.`);
        } else if (file.size > this.maxBytesValue) {
            this.reject(`Plik jest za duży (maksymalnie ${Math.round(this.maxBytesValue / MEGABYTE)} MB).`);
        } else if (file.size === 0) {
            this.reject("Plik jest pusty.");
        }
    }

    start(event) {
        const { file } = event.detail;

        this.total = file.size;
        this.filename = file.name;
        // add `flex` rather than relying on class order: `hidden` and `flex` are
        // both display utilities, and which wins is decided by the stylesheet
        this.progressTarget.classList.remove("hidden");
        this.progressTarget.classList.add("flex");
        this.setSubmitDisabled(true);
        this.render(0);
    }

    progress(event) {
        this.render(event.detail.progress);
    }

    // Without preventDefault Active Storage falls back to a window.alert.
    error(event) {
        event.preventDefault();
        this.progressTarget.classList.add("hidden");
        this.progressTarget.classList.remove("flex");
        this.setSubmitDisabled(false);
        this.showError("Nie udało się wysłać pliku na serwer. Spróbuj ponownie.");
    }

    // The form submits itself from here, so the bar is left full rather than
    // reset - it is about to be replaced by the next page either way.
    end() {
        this.render(100);
    }

    render(progress) {
        const percent = Math.min(100, Math.round(progress));
        const sent = formatSize((this.total * percent) / 100);

        this.barTarget.style.width = `${percent}%`;
        this.percentTarget.textContent = `${percent}%`;
        this.labelTarget.textContent = `${this.filename} - ${sent} / ${formatSize(this.total)}`;
    }

    reject(message) {
        this.inputTarget.value = "";
        this.showError(message);
    }

    showError(message) {
        this.errorTarget.textContent = message;
        this.errorTarget.classList.remove("hidden");
    }

    hideError() {
        this.errorTarget.textContent = "";
        this.errorTarget.classList.add("hidden");
    }

    setSubmitDisabled(disabled) {
        if (this.hasSubmitTarget) this.submitTarget.disabled = disabled;
    }
}
