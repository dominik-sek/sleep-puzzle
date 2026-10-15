---
version: 1
slug: "app-views-admin-products-form-html-erb"
primary_target: "app/views/admin/products/_form.html.erb"
related_targets: []
---

# Admin product URL regeneration

Mode: Operate. Extend the existing Polish-only editor for the owner. Preserve its layout, fields, upload behavior and palette; no new public UI or visual identity.

## Direction contract

THESIS: Change a product URL deliberately, with its exact next address visible before saving.

OWN-WORLD: Inherit the admin's warm dark surfaces, cream text, tan secondary text, amber actions, native buttons, existing form spacing and visible focus.

STORY: Edit the name, request an address preview, inspect it, and save the product. Ordinary renames preserve the URL. Previous addresses continue through permanent redirects.

FIRST VIEWPORT: Below the translated name pair, show the current path, a secondary generate control, a pending path/status, and a cancel control when regeneration is selected. Keep Save product as the form's single commit action. Wrap long URLs on narrow screens.

FORM: Local extension, code-led; no concept seed is applicable. Native buttons and an announced inline status; no modal. Preserve unsaved input on network errors and invalidate stale previews after name/kind edits.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
