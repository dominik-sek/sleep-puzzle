import { Controller } from "@hotwired/stimulus";

// Bridges the tree view and the accordions on the content blocks screen.
//
// Tree leaves are anchors pointing at "#section-<page>-<section>", which lives
// inside an accordion item's content. Three things stop that working on its own,
// all confirmed in the browser:
//
//   1. Turbo treats a same-page anchor as a full visit (turbo:click ->
//      turbo:visit -> turbo:load) and updates the URL via pushState, so
//      `hashchange` never fires for a click.
//   2. The target sits inside collapsed content, which the browser cannot
//      scroll to; opening it means clicking the accordion's own trigger.
//   3. This controller is on the outer element, so it connects before the
//      accordion controllers nested inside it - and their connect() resets every
//      item to closed, silently undoing an early open.
export default class extends Controller {
    // Set when the server rendered a section expanded (after saving, or adding or
    // removing a list item). The accordion is already open in the markup, so this
    // only has to bring it into view.
    static values = { open: String };

    connect() {
        this.onClick = this.handleClick.bind(this);
        this.onHashChange = this.handleHashChange.bind(this);

        this.element.addEventListener("click", this.onClick);
        // covers editing the anchor in the address bar and back/forward between
        // two anchors, neither of which reloads the document
        window.addEventListener("hashchange", this.onHashChange);

        this.revealUntilItSticks(window.location.hash);
        this.scrollToOpenSection();
    }

    scrollToOpenSection() {
        if (!this.hasOpenValue || this.openValue === "") return;

        const target = document.getElementById(this.openValue);
        if (!target) return;

        requestAnimationFrame(() => {
            target.scrollIntoView({ behavior: "smooth", block: "start" });
        });
    }

    disconnect() {
        this.element.removeEventListener("click", this.onClick);
        window.removeEventListener("hashchange", this.onHashChange);
        cancelAnimationFrame(this.retryFrame);
    }

    handleHashChange() {
        this.revealUntilItSticks(window.location.hash);
    }

    // Retries across frames because the accordion controllers below may not have
    // connected yet, and because the rest of the document may still be parsing.
    revealUntilItSticks(hash, attempts = 30) {
        if (this.reveal(hash) || attempts <= 0) return;

        this.retryFrame = requestAnimationFrame(() => this.revealUntilItSticks(hash, attempts - 1));
    }

    handleClick(event) {
        const link = event.target.closest('a[href^="#section-"]');

        if (link && this.element.contains(link)) {
            // keep Turbo out of it; we open and scroll ourselves
            event.preventDefault();
            const hash = link.getAttribute("href");
            this.revealUntilItSticks(hash);
            history.replaceState(history.state, "", hash);
            return;
        }

        // A section folder in the tree: let it expand as usual, and reveal the
        // matching accordion too, since clicking a section is the obvious way to
        // ask for it. `:scope > div > a` only matches folders whose children are
        // fields, so clicking a whole page does not jump to its first section.
        const folder = event.target.closest('button[data-action*="tree-view#toggle"]');
        if (!folder || !this.element.contains(folder)) return;

        const content = document.getElementById(folder.getAttribute("aria-controls"));
        const firstField = content?.querySelector(':scope > div > a[href^="#section-"]');
        if (firstField) this.revealUntilItSticks(firstField.getAttribute("href"));
    }

    // Returns whether the section ended up open, so the caller knows to stop retrying.
    reveal(hash) {
        if (!hash || hash.length < 2) return true;

        // Not found is not the same as nothing to do: on first load this
        // controller connects as soon as the outer element is parsed, before the
        // accordion items further down the document exist.
        const target = document.getElementById(decodeURIComponent(hash.slice(1)));
        if (!target) return false;
        if (!this.element.contains(target)) return true;

        const item = target.closest('[data-accordion-target="item"]');
        const trigger = item?.querySelector('[data-accordion-target="trigger"]');
        if (!trigger) return false;

        const accordionElement = item.closest('[data-controller~="accordion"]');
        if (!accordionElement) return false;
        if (!this.application.getControllerForElementAndIdentifier(accordionElement, "accordion")) return false;

        if (trigger.getAttribute("aria-expanded") === "false") {
            trigger.click();
        }

        if (trigger.getAttribute("aria-expanded") !== "true") return false;

        // let the grid-rows transition start before scrolling to the now-open row
        requestAnimationFrame(() => {
            target.scrollIntoView({ behavior: "smooth", block: "start" });
        });

        return true;
    }
}
