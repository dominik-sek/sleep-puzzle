import { application } from "../controllers/application"

// Keep the shared navigation and form controllers ready immediately. Only the
// two large features absent from most pages cross an asynchronous boundary.
const features = [
    {
        selector: '[data-controller~="cally"]',
        load: () => import("../controllers/cally_controller").then(({ default: controller }) => {
            application.register("cally", controller)
        })
    },
    {
        selector: "trix-editor",
        load: () => import("./rich_text_editor")
    }
]

function prepare(root) {
    return Promise.all(features.filter(({ selector }) => (
        root.matches?.(selector) || root.querySelector?.(selector)
    )).map((feature) => {
        // Share in-flight imports across render events and mutations. A failed
        // request can be retried on the next visit instead of poisoning the tab.
        feature.promise ||= feature.load().catch((error) => {
            feature.promise = null
            throw error
        })
        return feature.promise
    }))
}

function report(error) {
    console.error("Could not load a page feature", error)
}

// Pause Turbo's page/frame replacement until custom elements and controllers
// are ready, so a newly visible calendar accepts the first interaction.
for (const eventName of ["turbo:before-render", "turbo:before-frame-render"]) {
    document.addEventListener(eventName, (event) => {
        const root = event.detail.newBody || event.detail.newFrame
        if (!features.some(({ selector }) => root.matches?.(selector) || root.querySelector(selector))) return

        event.preventDefault()
        prepare(root).catch(report).finally(() => event.detail.resume())
    })
}

// Covers initial HTML and Turbo Stream insertions, including a rich editor
// added to a section that previously contained only plain-text fields.
new MutationObserver((mutations) => {
    for (const mutation of mutations) {
        if (mutation.type === "attributes") prepare(mutation.target).catch(report)
        for (const node of mutation.addedNodes) {
            if (node.nodeType === Node.ELEMENT_NODE) prepare(node).catch(report)
        }
    }
}).observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ["data-controller"] })

prepare(document).catch(report)
