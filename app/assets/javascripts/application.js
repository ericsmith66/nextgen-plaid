// Entry point for application JavaScript.
//
// This project uses Importmap, so this file is loaded as an ES module via
// `javascript_importmap_tags` (i.e., `import "application"`).
//
// NOTE:
// - We intentionally load Hotwire here so Turbo Streams + Stimulus controllers
//   work everywhere (including `/admin/sap_collaborate`).

import "@hotwired/turbo-rails"
import "controllers"
