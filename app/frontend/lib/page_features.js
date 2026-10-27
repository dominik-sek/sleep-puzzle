import { controllerFeatures } from "../controllers"

// Match capabilities in the incoming markup, rather than guessing from the URL:
// the same controls can arrive in an initial page, a Turbo frame, or a stream.
const features = [
    ...controllerFeatures,
    {
        selector: "input[data-direct-upload-url]",
        load: () => import("@rails/activestorage").then((storage) => storage.start())
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
// are ready, so newly visible controls accept the first interaction.
for (const eventName of ["turbo:before-render", "turbo:before-frame-render"]) {
    document.addEventListener(eventName, (event) => {
        const root = event.detail.newBody || event.detail.newFrame
        if (!features.some(({ selector }) => root.matches?.(selector) || root.querySelector(selector))) return

        event.preventDefault()
        prepare(root).catch(report).finally(() => event.detail.resume())
    })
}

// Stream templates are still detached here: load their controllers before the
// controls become visible, just as for full-page and frame navigations.
document.addEventListener("turbo:before-stream-render", (event) => {
    const render = event.detail.render
    event.detail.render = async (stream) => {
        await prepare(stream.templateElement.content).catch(report)
        return render(stream)
    }
})

// Covers initial HTML and Turbo Stream insertions, including a rich editor
// added to a section that previously contained only plain-text fields.
new MutationObserver((mutations) => {
    for (const mutation of mutations) {
        if (mutation.type === "attributes") prepare(mutation.target).catch(report)
        for (const node of mutation.addedNodes) {
            if (node.nodeType === Node.ELEMENT_NODE) prepare(node).catch(report)
        }
    }
}).observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ["data-controller", "data-direct-upload-url"] })

prepare(document).catch(report)
