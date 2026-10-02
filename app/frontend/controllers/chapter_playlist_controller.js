import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["player", "chapter"];

    connect() {
        if (this.chapterTargets.length) this.activate(0, false);
    }

    select(event) {
        this.activate(Number(event.currentTarget.dataset.index), true);
    }

    next() {
        if (this.index + 1 < this.chapterTargets.length) this.activate(this.index + 1, true);
    }

    activate(index, play) {
        const chapter = this.chapterTargets[index];
        if (!chapter) return;

        this.index = index;
        this.chapterTargets.forEach((button, position) => {
            const selected = position === index;
            button.setAttribute("aria-pressed", String(selected));
            button.classList.toggle("border-accent", selected);
            button.classList.toggle("border-border-input", !selected);
        });
        this.playerTarget.src = chapter.dataset.src;
        this.playerTarget.setAttribute("aria-label", chapter.dataset.label);
        if (play) {
            this.playerTarget.load();
            this.playerTarget.play().catch(() => {});
        }
    }
}
