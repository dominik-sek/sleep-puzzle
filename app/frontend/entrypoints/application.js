import '~/entrypoints/application.css'
import "@hotwired/turbo-rails"

import '~/controllers'
import '~/lib/page_features'

// Keep rendered rich text styled on every page. The editor's JavaScript loads
// only when a <trix-editor> is present (including Turbo visits and streams).
import "trix/dist/trix.css"
