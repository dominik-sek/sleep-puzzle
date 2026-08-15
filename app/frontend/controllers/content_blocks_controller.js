import { Controller } from "@hotwired/stimulus";

// Bridges the tree view and the accordions on the content blocks screen.
//
// Tree leaves are anchors pointing at "#section-<page>-<section>", which lives
// inside an accordion item's content. Two things stop that from working on its
// own, both confirmed in the browser:
//
//   1. Turbo treats a same-page anchor as a full visit (turbo:click ->
//      turbo:visit -> turbo:load) and updates the URL via pushState, so
//      `hashchange` never fires.
//   2. The target sits inside collapsed content, which the browser cannot
//      scroll to, and opening it means clicking the accordion's own trigger.
//
// So the click is handled here instead, which also sidesteps a connect-order
// race: this controller is on the outer element and connects before the
// accordion controllers nested inside it, making an early trigger.click() a
// no-op.
export default class extends Controller {
    connect() {
        this.onClick = this.handleClick.bind(this);
        this.element.addEventListener("click", this.onClick);

        // Someone opening .../content_blocks#section-home-audio directly, or a
        // Turbo restoration visit. This controller sits on the outer element and
        // connects before the accordion controllers nested inside it, and their
        // connect() resets every item to closed — so a single deferred attempt
        // races them and loses. Retry across a few frames until it sticks.
        console.log('[cb] connect hash=', window.location.hash, 'readyState=', document.readyState);
        this.revealUntilItSticks(window.location.hash);
    }

    disconnect() {
        this.element.removeEventListener("click", this.onClick);
        cancelAnimationFrame(this.retryFrame);
    }

    revealUntilItSticks(hash, attempts = 30) {
        const ok = this.reveal(hash);
        console.log('[cb] attempt', 30 - attempts, 'hash=', hash, 'ok=', ok);
        if (ok || attempts <= 0) return;

        this.retryFrame = requestAnimationFrame(() => this.revealUntilItSticks(hash, attempts - 1));
    }

    handleClick(event) {
        const link = event.target.closest('a[href^="#section-"]');

        if (link && this.element.contains(link)) {
            // keep Turbo out of it; we move and scroll ourselves
            event.preventDefault();
            const hash = link.getAttribute("href");
            this.reveal(hash);
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
        if (firstField) this.reveal(firstField.getAttribute("href"));
    }

    // Returns whether the section ended up open, so the caller knows to stop retrying.
    reveal(hash) {
        if (!hash || hash.length < 2) return true;

        // Not found is not the same as nothing to do: on first load this
        // controller connects as soon as the outer element is parsed, before the
        // accordion items further down the document exist. Report failure so the
        // caller retries rather than giving up on a DOM that is still arriving.
        const target = document.getElementById(decodeURIComponent(hash.slice(1)));
        if (!target) return false;
        if (!this.element.contains(target)) return true;

        const item = target.closest('[data-accordion-target="item"]');
        const trigger = item?.querySelector('[data-accordion-target="trigger"]');
        if (!trigger) return false;

        // Wait for the accordion controller itself, not just its markup. Its
        // connect() resets every item to closed, so opening one before it is up
        // gets silently undone a moment later.
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
