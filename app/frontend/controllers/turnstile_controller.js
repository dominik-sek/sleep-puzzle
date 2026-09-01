import { Controller } from "@hotwired/stimulus";

const API_URL = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";

// One load for the whole page, however many widgets ask for it, and shared
// between the first render and every Turbo frame replacement after it.
let apiLoad = null;

function loadApi() {
    if (apiLoad) return apiLoad;

    apiLoad = new Promise((resolve, reject) => {
        const script = document.createElement("script");
        script.src = API_URL;
        script.async = true;
        script.defer = true;
        script.onload = resolve;
        script.onerror = () => {
            // let a later connect try again rather than caching the failure
            apiLoad = null;
            reject(new Error("Turnstile could not be loaded"));
        };
        document.head.appendChild(script);
    });

    return apiLoad;
}

// Renders the Turnstile widget explicitly rather than letting api.js scan the
// page on load. The contact form lives in a Turbo frame and is replaced whole on
// a validation error, and the auto-scan only ever runs once - so an auto-rendered
// widget would come back as an empty div, leaving the visitor with a form they
// cannot submit. Rendering on connect also means the replaced form gets a fresh
// token, which matters because a token is single use.
export default class extends Controller {
    static values = { siteKey: String, action: String, theme: String, language: String,
                      eager: Boolean, unavailable: String };

    // Deferred rather than loaded on connect. README: "a visitor who only reads
    // the site makes no third-party request at all" - loading Cloudflare on page
    // render made that false for anyone who merely opened the contact page, which
    // is now where every "not ready to buy" link on the site points. Paddle.js
    // already works this way ("loads only when a checkout opens"); this matches it.
    //
    // eager: true is passed by a form that has come back from a rejected submit.
    // That visitor is mid-task and has already spent a token, so waiting for
    // another focus before minting the next one would leave them looking at a gap
    // where the widget was.
    connect() {
        if (this.eagerValue) return this.load();

        // once: the listener is only ever needed to start the load
        this.startLoad = () => this.load();
        this.form?.addEventListener("focusin", this.startLoad, { once: true });
        this.form?.addEventListener("input", this.startLoad, { once: true });
    }

    disconnect() {
        this.form?.removeEventListener("focusin", this.startLoad);
        this.form?.removeEventListener("input", this.startLoad);

        if (this.widgetId === undefined) return;

        window.turnstile?.remove(this.widgetId);
        this.widgetId = undefined;
    }

    get form() {
        return this.element.closest("form");
    }

    load() {
        loadApi()
            .then(() => this.render())
            .catch(() => this.reportUnavailable());
    }

    // A visitor whose network, extension or browser blocks Cloudflare would
    // otherwise see an empty gap, submit, and be told they might be a robot -
    // with no way to ever succeed. Say so where the widget would have been.
    reportUnavailable() {
        if (!this.element.isConnected) return;

        this.element.textContent = this.unavailableValue;
        this.element.className = "mt-1.5 text-t6 text-accent-terracotta";
    }

    render() {
        // disconnected again while the script was still loading
        if (!this.element.isConnected) return;

        this.widgetId = window.turnstile.render(this.element, {
            sitekey: this.siteKeyValue,
            action: this.actionValue,
            theme: this.themeValue || "auto",
            language: this.languageValue || "auto",
        });
    }
}
