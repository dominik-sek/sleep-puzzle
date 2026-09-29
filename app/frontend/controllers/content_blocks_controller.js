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
    static values = { open: String, page: String, pages: Object };
    static targets = ["frame", "pageSelect", "localeSelect", "status"];

    connect() {
        this.onClick = this.handleClick.bind(this);
        this.onHashChange = this.handleHashChange.bind(this);
        this.onInput = this.handleInput.bind(this);
        this.onFrameLoad = this.frameLoaded.bind(this);
        this.previewTargets = new Map();
        this.selectedSection = this.hasOpenValue ? this.openValue.replace(/^section-/, "").replace("-", ".") : null;

        this.element.addEventListener("click", this.onClick);
        this.element.addEventListener("input", this.onInput);
        this.element.addEventListener("trix-change", this.onInput);
        this.frameTarget.addEventListener("load", this.onFrameLoad);
        if (this.frameTarget.contentDocument?.readyState === "complete") this.frameLoaded();
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
        this.element.removeEventListener("input", this.onInput);
        this.element.removeEventListener("trix-change", this.onInput);
        this.frameTarget.removeEventListener("load", this.onFrameLoad);
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
            const section = document.querySelector(hash)?.dataset.previewSection;
            if (section) this.selectSection(section);
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
        if (firstField) {
            this.revealUntilItSticks(firstField.getAttribute("href"));
            const section = document.querySelector(firstField.getAttribute("href"))?.dataset.previewSection;
            if (section) this.selectSection(section);
        }
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

    changePage() {
        this.selectedSection = null;
        this.pageValue = this.pageSelectTarget.value;
        this.loadPreview();
    }

    changeLocale() {
        this.loadPreview();
    }

    showSection(event) {
        const section = event.currentTarget.closest("[data-preview-section]")?.dataset.previewSection;
        if (!section) return;

        this.selectSection(section);
        if (!window.matchMedia("(min-width: 1024px)").matches) {
            this.frameTarget.scrollIntoView({ behavior: "smooth", block: "center" });
        }
    }

    selectSection(section) {
        this.selectedSection = section;
        const page = section.split(".")[0];
        if (page !== this.pageValue) {
            this.pageValue = page;
            this.pageSelectTarget.value = page;
            this.loadPreview();
        } else {
            this.highlightSection();
        }
    }

    previewConfig() {
        return this.pagesValue[this.pageValue]?.[this.localeSelectTarget.value];
    }

    loadPreview() {
        const url = this.previewConfig()?.url;
        if (!url) {
            this.statusTarget.textContent = "Ta strona nie ma jeszcze podglądu.";
            return;
        }

        this.previewTargets.clear();
        this.statusTarget.textContent = "Ładowanie podglądu…";
        this.frameTarget.src = url;
    }

    frameLoaded() {
        const doc = this.frameTarget.contentDocument;
        if (!doc?.body) {
            this.statusTarget.textContent = "Nie udało się otworzyć podglądu.";
            return;
        }

        // The iframe has no script permission. Keep its links and forms inert,
        // while still allowing the owner to scroll through the real page.
        doc.addEventListener("click", (event) => {
            if (event.target.closest("a, button")) event.preventDefault();
        });
        doc.addEventListener("submit", (event) => event.preventDefault());

        const style = doc.createElement("style");
        style.textContent = ".cms-preview-highlight { outline: 2px solid #e6a37b !important; outline-offset: 4px; border-radius: 3px; }";
        doc.head.appendChild(style);

        const walker = doc.createTreeWalker(doc.body, NodeFilter.SHOW_TEXT);
        const textNodes = [];
        while (walker.nextNode()) {
            const node = walker.currentNode;
            if (!node.parentElement?.closest("script, style, noscript")) textNodes.push(node);
        }

        this.previewEntries = (this.previewConfig()?.entries || []).map((entry) => ({ ...entry, matches: [] }));
        for (const entry of this.previewEntries) {
            if (!entry.text) continue;

            const matches = entry.type === "rich"
                ? [...doc.querySelectorAll(".trix-content")].filter((element) => this.normalize(element.textContent) === entry.text)
                : textNodes.filter((node) => this.normalize(node.textContent) === entry.text);

            entry.matches = matches.map((node) => ({ node, original: entry.type === "rich" ? node.innerHTML : node.textContent }));
            if (entry.key && matches.length) this.previewTargets.set(entry.key, entry);
        }

        this.highlightSection();
        this.updateLiveValues();
    }

    normalize(text) {
        return (text || "").replace(/\s+/g, " ").trim();
    }

    highlightSection() {
        const doc = this.frameTarget.contentDocument;
        if (!doc?.body) return;
        doc.querySelectorAll(".cms-preview-highlight").forEach((element) => element.classList.remove("cms-preview-highlight"));

        if (!this.selectedSection) {
            this.statusTarget.textContent = "Wybierz sekcję, aby zaznaczyć jej miejsce na stronie.";
            return;
        }

        const entries = this.previewEntries?.filter((entry) => entry.section === this.selectedSection) || [];
        const elements = entries.flatMap((entry) => entry.matches.map(({ node }) => entry.type === "rich" ? node : node.parentElement));
        const visible = elements.filter((element) => element && element.getClientRects().length);
        if (!visible.length) {
            this.statusTarget.textContent = "Ta treść nie jest widoczna w bieżącym stanie strony. Może pojawić się dopiero po dodaniu danych lub wykonaniu akcji.";
            return;
        }

        visible.forEach((element) => element.classList.add("cms-preview-highlight"));
        // scrollIntoView on a node inside an iframe can also move the outer
        // admin document. Keep automatic positioning inside the preview only.
        const frameWindow = this.frameTarget.contentWindow;
        const top = visible[0].getBoundingClientRect().top + frameWindow.scrollY - frameWindow.innerHeight / 2;
        frameWindow.scrollTo({ top: Math.max(0, top), behavior: "smooth" });
        this.statusTarget.textContent = "Zaznaczono miejsce wybranej sekcji na stronie.";
    }

    handleInput(event) {
        if (event.target.dataset.previewKey) this.updateLiveValues(event.target.dataset.previewKey);
    }

    inputValue(key, locale) {
        const field = [...this.element.querySelectorAll("[data-preview-key]")]
            .find((input) => input.dataset.previewKey === key && input.dataset.previewLocale === locale);
        if (!field) return null;

        if (field.tagName === "TRIX-EDITOR") {
            return document.getElementById(field.getAttribute("input"))?.value || "";
        }
        return field.value;
    }

    liveText(entry) {
        const locale = this.localeSelectTarget.value;
        const chosen = this.inputValue(entry.key, locale);
        const polish = this.inputValue(entry.key, "pl");
        const raw = chosen?.trim() || (locale === "en" ? polish?.trim() : null) || entry.defaults?.[locale] || "";
        if (entry.type !== "rich") return this.normalize(raw);

        const template = document.createElement("template");
        template.innerHTML = raw;
        return this.normalize(template.content.textContent);
    }

    updateLiveValues(key = null) {
        const entries = key ? [this.previewTargets.get(key)].filter(Boolean) : this.previewTargets.values();
        for (const entry of entries) {
            const text = this.liveText(entry);
            if (text === entry.text && !entry.liveEdited) continue;

            for (const match of entry.matches) {
                if (text === entry.text) {
                    if (entry.type === "rich") match.node.innerHTML = match.original;
                    else match.node.textContent = match.original;
                } else {
                    match.node.textContent = text;
                }
            }
            entry.liveEdited = text !== entry.text;
        }
    }
}
