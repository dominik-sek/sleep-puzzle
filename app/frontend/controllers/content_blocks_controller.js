import { Controller } from "@hotwired/stimulus";

// One selected section, a searchable navigator, and an optional live preview.
export default class extends Controller {
    static values = { section: String, page: String, pages: Object, lang: String };
    static targets = [
        "workspace", "preview", "previewButton", "previewButtonLabel", "frame",
        "pageSelect", "localeSelect", "status", "search", "navigation", "results",
        "resultCount", "noResults", "searchResult", "editorPage", "languageTab",
        "localePanel", "langInput", "englishNote", "form"
    ];

    connect() {
        this.selectedSection = this.sectionValue;
        this.previewMatches = new Map();
        this.previewOpen = false;
        this.previewEverOpened = false;
        this.dirty = false;
        this.saving = false;
        this.navigationApproved = false;
        this.initialFormState = this.formSnapshot();
        // Turbo may restore a snapshot captured with the preview open.
        this.previewTarget.hidden = true;
        this.workspaceTarget.dataset.previewOpen = "false";
        this.previewButtonTarget.setAttribute("aria-expanded", "false");
        this.previewButtonLabelTarget.textContent = "Podgląd";

        this.onInput = this.handleInput.bind(this);
        this.onClick = this.handleClick.bind(this);
        this.onBeforeVisit = this.beforeVisit.bind(this);
        this.onBeforeUnload = this.beforeUnload.bind(this);
        this.onFrameLoad = this.frameLoaded.bind(this);
        this.onTrixInitialize = this.trixInitialized.bind(this);
        this.onSubmitEnd = this.submitEnded.bind(this);

        this.element.addEventListener("input", this.onInput);
        this.element.addEventListener("change", this.onInput);
        this.element.addEventListener("trix-change", this.onInput);
        this.element.addEventListener("trix-initialize", this.onTrixInitialize);
        this.element.addEventListener("click", this.onClick, true);
        this.element.addEventListener("turbo:submit-end", this.onSubmitEnd);
        this.frameTarget.addEventListener("load", this.onFrameLoad);
        document.addEventListener("turbo:before-visit", this.onBeforeVisit);
        window.addEventListener("beforeunload", this.onBeforeUnload);
    }

    disconnect() {
        this.element.removeEventListener("input", this.onInput);
        this.element.removeEventListener("change", this.onInput);
        this.element.removeEventListener("trix-change", this.onInput);
        this.element.removeEventListener("trix-initialize", this.onTrixInitialize);
        this.element.removeEventListener("click", this.onClick, true);
        this.element.removeEventListener("turbo:submit-end", this.onSubmitEnd);
        this.frameTarget.removeEventListener("load", this.onFrameLoad);
        document.removeEventListener("turbo:before-visit", this.onBeforeVisit);
        window.removeEventListener("beforeunload", this.onBeforeUnload);
    }

    formSnapshot() {
        return JSON.stringify([...new FormData(this.formTarget).entries()]
            .filter(([name]) => !["authenticity_token", "lang"].includes(name))
            .map(([name, value]) => [name, value instanceof File
                ? (value.name ? [value.name, value.size, value.lastModified] : null)
                : value]));
    }

    trixInitialized() {
        // Trix may normalize its hidden field when it starts; that is not an edit.
        if (!this.dirty) this.initialFormState = this.formSnapshot();
    }

    handleInput(event) {
        if (this.formTarget.contains(event.target)) {
            queueMicrotask(() => { this.dirty = this.formSnapshot() !== this.initialFormState; });
        }
        if (event.target.dataset.previewKey) this.updateLiveValues(event.target.dataset.previewKey);
    }

    confirmDiscard() {
        return !this.dirty || window.confirm("Masz niezapisane zmiany w tej sekcji. Opuścić ją bez zapisu?");
    }

    approveNavigation() {
        this.navigationApproved = true;
        window.setTimeout(() => { this.navigationApproved = false; }, 2000);
    }

    handleClick(event) {
        const link = event.target.closest("a[href]");
        if (!link || !this.element.contains(link)) return;

        const url = new URL(link.href, window.location.href);
        if (url.pathname.startsWith("/admin/content_blocks") || url.pathname.startsWith("/admin/content_items")) {
            this.applyLanguage(url);
            link.setAttribute("href", url.pathname + url.search + url.hash);
        }

        if (!this.confirmDiscard()) {
            event.preventDefault();
            event.stopImmediatePropagation();
            return;
        }
        this.approveNavigation();
    }

    beforeVisit(event) {
        if (this.saving || this.navigationApproved || !this.dirty) return;
        if (!this.confirmDiscard()) event.preventDefault();
        else this.approveNavigation();
    }

    beforeUnload(event) {
        if (this.saving || this.navigationApproved || !this.dirty) return;
        event.preventDefault();
        event.returnValue = "";
    }

    submit() {
        this.saving = true;
        this.approveNavigation();
    }

    submitEnded(event) {
        if (event.target !== this.formTarget || event.detail.success) return;
        this.saving = false;
        this.navigationApproved = false;
    }

    applyLanguage(url) {
        if (this.langValue === "en") url.searchParams.set("lang", "en");
        else url.searchParams.delete("lang");
    }

    syncLinkLanguages() {
        for (const link of this.element.querySelectorAll('a[href^="/admin/content_blocks"], a[href^="/admin/content_items"]')) {
            const url = new URL(link.href, window.location.href);
            this.applyLanguage(url);
            link.setAttribute("href", url.pathname + url.search + url.hash);
        }
    }

    changeEditorPage(event) {
        if (!this.confirmDiscard()) {
            event.target.value = this.sectionValue.split(".")[0];
            return;
        }
        const url = new URL(window.location.href);
        url.searchParams.delete("open");
        url.searchParams.set("page", event.target.value);
        this.applyLanguage(url);
        this.approveNavigation();
        window.Turbo.visit(url.toString());
    }

    search() {
        const query = this.normalizeSearch(this.searchTarget.value);
        this.navigationTarget.hidden = query.length > 0;
        this.resultsTarget.hidden = query.length === 0;
        if (!query) return;

        let count = 0;
        for (const result of this.searchResultTargets) {
            const matches = this.normalizeSearch(result.dataset.searchText).includes(query);
            result.hidden = !matches;
            if (matches) count += 1;
        }
        this.resultCountTarget.textContent = count === 1 ? "1 wynik" : `${count} wyników`;
        this.noResultsTarget.hidden = count > 0;
    }

    normalizeSearch(text) {
        return (text || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().trim();
    }

    selectLanguage(event) {
        const language = event.currentTarget.dataset.lang;
        if (language === this.langValue) return;

        this.langValue = language;
        this.langInputTarget.value = language;
        for (const panel of this.localePanelTargets) panel.hidden = panel.dataset.lang !== language;
        for (const tab of this.languageTabTargets) {
            const selected = tab.dataset.lang === language;
            tab.setAttribute("aria-pressed", String(selected));
            tab.classList.toggle("bg-accent", selected);
            tab.classList.toggle("text-ink", selected);
            tab.classList.toggle("text-tan", !selected);
        }
        this.englishNoteTarget.hidden = language !== "en";
        if (!this.previewEverOpened) this.localeSelectTarget.value = language;

        const url = new URL(window.location.href);
        this.applyLanguage(url);
        history.replaceState(history.state, "", url);
        this.syncLinkLanguages();
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
        this.previewEverOpened = true;
        if (!this.frameTarget.hasAttribute("src")) this.loadPreview();
        else this.frameLoaded();
    }

    closePreview() {
        this.previewOpen = false;
        this.previewTarget.hidden = true;
        this.workspaceTarget.dataset.previewOpen = "false";
        this.previewButtonTarget.setAttribute("aria-expanded", "false");
        this.previewButtonLabelTarget.textContent = "Podgląd";
        this.previewButtonTarget.focus();
    }

    changePage() {
        this.selectedSection = null;
        this.pageValue = this.pageSelectTarget.value;
        this.loadPreview();
    }

    changeLocale() {
        this.loadPreview();
    }

    showSection() {
        if (!this.previewOpen) this.openPreview();
        this.selectSection(this.sectionValue);
        if (!window.matchMedia("(min-width: 1024px)").matches) {
            this.previewTarget.scrollIntoView({ behavior: "smooth", block: "start" });
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

        this.previewMatches.clear();
        this.statusTarget.textContent = "Ładowanie podglądu…";
        this.frameTarget.src = url;
    }

    frameLoaded() {
        if (!this.frameTarget.hasAttribute("src")) return;
        const doc = this.frameTarget.contentDocument;
        if (!doc?.body) {
            this.statusTarget.textContent = "Nie udało się otworzyć podglądu.";
            return;
        }

        if (!doc.documentElement.dataset.cmsPreviewReady) {
            // The iframe has no script permission. Keep its links and forms inert,
            // while still allowing the owner to scroll through the real page.
            doc.addEventListener("click", (event) => {
                if (event.target.closest("a, button")) event.preventDefault();
            });
            doc.addEventListener("submit", (event) => event.preventDefault());

            const style = doc.createElement("style");
            style.textContent = ".cms-preview-highlight { outline: 2px solid #e6a37b !important; outline-offset: 4px; border-radius: 3px; }";
            doc.head.appendChild(style);
            doc.documentElement.dataset.cmsPreviewReady = "true";
        }

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
            if (entry.key && matches.length) this.previewMatches.set(entry.key, entry);
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
        const entries = key ? [this.previewMatches.get(key)].filter(Boolean) : this.previewMatches.values();
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
