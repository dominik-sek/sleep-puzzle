import '~/entrypoints/application.css'
import "@hotwired/turbo-rails"

// Direct uploads: the admin's audio file goes to the staging service straight
// from the browser, which is what makes a real progress percentage possible.
// Action Text vendors its own copy but only autostarts it when window.ActiveStorage
// is set, which it never is here - so this is the one set of listeners.
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
import '~/controllers'
import '~/lib/page_features'

// Keep rendered rich text styled on every page. The editor's JavaScript loads
// only when a <trix-editor> is present (including Turbo visits and streams).
import "trix/dist/trix.css"
