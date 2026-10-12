import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["image", "fallback"];

    connect() {
        // Cached failures can finish before Stimulus attaches the error action.
        if (this.hasImageTarget && this.imageTarget.complete && this.imageTarget.naturalWidth === 0) {
            this.showFallback();
        }
    }

    showFallback() {
        if (!this.hasImageTarget || !this.hasFallbackTarget) return;

        this.imageTarget.hidden = true;
        this.fallbackTarget.hidden = false;
    }
}
