import '~/entrypoints/application.css'
import "@hotwired/turbo-rails"

// Direct uploads: the admin's audio file goes to the staging service straight
// from the browser, which is what makes a real progress percentage possible.
// Action Text vendors its own copy but only autostarts it when window.ActiveStorage
// is set, which it never is here - so this is the one set of listeners.
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
import '~/controllers'
import "cally"

// Action Text: trix registers the <trix-editor> element, @rails/actiontext wires
// attachment uploads through Active Storage. trix's own stylesheet is imported
// here rather than in application.css so Vite resolves it out of node_modules;
// the dark theming on top lives in application.css.
import "trix"
import "trix/dist/trix.css"
import "@rails/actiontext"
