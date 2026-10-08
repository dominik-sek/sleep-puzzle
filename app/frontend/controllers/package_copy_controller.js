import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static values = { summaryLimit: Number, highlightsLimit: Number, highlightLength: Number };

    connect() {
        this.refresh();
    }

    refresh() {
        this.element.querySelectorAll("[data-package-copy-kind]").forEach(input => {
            const warning = input.parentElement.querySelector("[data-copy-warning]");
            if (!warning) return;
            const messages = [];
            if (input.dataset.packageCopyKind === "summary") {
                const length = Array.from(input.value).length;
                if (length > this.summaryLimitValue) messages.push(`Opis ma ${length} znaków. Zalecane maksimum: ${this.summaryLimitValue}. Pełny tekst pozostanie w szczegółach.`);
            } else {
                const entries = input.value.split("\n").map(line => line.trim()).filter(Boolean);
                if (entries.length > this.highlightsLimitValue) messages.push(`Wpisano ${entries.length} wyróżników. Karta pokaże pierwsze ${this.highlightsLimitValue}, pozostałe będą w szczegółach.`);
                if (entries.some(entry => Array.from(entry).length > this.highlightLengthValue)) messages.push(`Skróć wyróżniki do ${this.highlightLengthValue} znaków każdy; nie przenoś tu pełnych zasad współpracy.`);
            }
            warning.textContent = messages.join(" ");
            warning.hidden = messages.length === 0;
        });
    }
}
