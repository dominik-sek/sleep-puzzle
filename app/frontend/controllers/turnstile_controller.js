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
// a validation error, and the auto-scan only ever runs once — so an auto-rendered
// widget would come back as an empty div, leaving the visitor with a form they
// cannot submit. Rendering on connect also means the replaced form gets a fresh
// token, which matters because a token is single use.
export default class extends Controller {
    static values = { siteKey: String, action: String, theme: String, language: String };

    connect() {
        loadApi()
            .then(() => this.render())
            .catch((error) => console.error(error));
    }

    disconnect() {
        if (this.widgetId === undefined) return;

        window.turnstile?.remove(this.widgetId);
        this.widgetId = undefined;
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
