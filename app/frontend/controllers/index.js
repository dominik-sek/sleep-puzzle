import { application } from "./application"
import { registerControllers } from "stimulus-vite-helpers"

// The booking calendar brings its own custom elements and date library. It is
// registered by page_features before a page containing it is rendered.
const controllers = import.meta.glob(["./**/*_controller.js", "!./cally_controller.js"], { eager: true })
registerControllers(application, controllers)
