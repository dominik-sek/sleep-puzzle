import '~/entrypoints/application.css'
import "@hotwired/turbo-rails"
import '~/controllers'
import "cally"

// Action Text: trix registers the <trix-editor> element, @rails/actiontext wires
// attachment uploads through Active Storage. trix's own stylesheet is imported
// here rather than in application.css so Vite resolves it out of node_modules;
// the dark theming on top lives in application.css.
import "trix"
import "trix/dist/trix.css"
import "@rails/actiontext"
