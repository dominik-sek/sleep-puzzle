import { application } from "./application"
import { identifierForGlobKey, registerControllers } from "stimulus-vite-helpers"

// Shared chrome and public form interactions are ready without another request.
// Keep the matching exclusions below in sync when changing this small set.
const shared = import.meta.glob([
    "./navbar_controller.js", "./locale_controller.js", "./flash_controller.js",
    "./toast_controller.js", "./avatar_controller.js", "./image_fallback_controller.js",
    "./cart_focus_controller.js", "./turnstile_controller.js"
], { eager: true })
registerControllers(application, shared)

// Vite gives each optional controller a real asynchronous boundary, including
// admin tools and the dependencies of carousel, tooltip and calendar controls.
const optional = import.meta.glob([
    "./**/*_controller.js",
    "!./navbar_controller.js", "!./locale_controller.js", "!./flash_controller.js",
    "!./toast_controller.js", "!./avatar_controller.js", "!./image_fallback_controller.js",
    "!./cart_focus_controller.js", "!./turnstile_controller.js"
])

export const controllerFeatures = Object.entries(optional).map(([path, load]) => {
    const identifier = identifierForGlobKey(path)
    return {
        selector: `[data-controller~="${identifier}"]`,
        load: () => load().then(({ default: controller }) => application.register(identifier, controller))
    }
})
