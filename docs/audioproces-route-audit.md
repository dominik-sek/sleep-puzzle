# Audio catalogue and product-page audit

Reassessed 14 October 2026 for multiple audioprocesy and multiple bajki audio.
Targets: `/audioproces`, `/products/2`; `/products` and navigation inspected as
supporting context. Audit only: no application or catalogue changes.

Implementation follow-up: the requested hardening now lists all published programs
on `/audioproces`, retaining per-product detail URLs. Product 2's guarded migration
declares 24 chapters, so its one current recording remains a preview and new sales
are paused. Incomplete programs no longer show partial duration as total length.
Suitability and topic disclosure now live on individual program pages. The
findings and score below record the audit before these changes, not a new audit.

Clarify/layout follow-up: navigation and the footer now expose Bajki audio at
`/products#bajki`. The shop separates both audio kinds and 1:1 offers, with stable
section anchors, independently capped grids, shorter product-card descriptions,
and full descriptions retained on product pages. Shared editable delivery facts
are rendered consistently and explicitly apply to audio. Empty categories retain
their destination and an editable message. Mobile navigation closes on a category
selection so the destination heading remains visible below the sticky navbar.

Distill/adapt follow-up: reusable product-kind detail partials now separate
program suitability and expandable topics from story descriptions. The chapter
outline follows the program overview; duration is shown once. Product identity
precedes both trailer and fallback media on phones, and the back link has a 44px
minimum target. Narrow/enlarged-text checks cover long names, in-cart actions,
chapter metadata and confirmation messages. These are implementation follow-ups;
the original score below has not been recalculated.

## Implementation integrity verdict: fail for the planned catalogue

The product model already supports many records in two audio kinds. Discovery
still assumes one promoted audioprocess: the landing selects `ordered.first` and
renders its full sales page. Product detail pages already resolve a specific ID.
This is a mismatch between the collection entry point and the catalogue model,
not a reason to remove individual product URLs.

**This reassessment supersedes the earlier recommendation to redirect
`/products/2` to `/audioproces`. Keep individual product detail URLs.**

## Route decision

| URL | Responsibility | Content depth |
| --- | --- | --- |
| `/audioproces` | Audioprocesy collection | Short category introduction, all published programs, concise suitability summaries, prices and links to individual products. |
| `/products/:id` | One product's canonical sales page | Product-specific explanation, preview/trailer, price, delivery/access facts, purchase state and full details. Works for both kinds. |
| `/products` | All-offers catalogue | Clearly separated Audioprocesy and Bajki audio sections; retain the existing separate 1:1 section. |
| `/products#bajki` | Proposed direct entry into the stories section | A simple navigation destination; this anchor does not exist yet. |
| `/packages` | Consultation offers | Existing 1:1 destination. |

Retain `/audioproces` initially to preserve existing links; its visible category
label should become “Audioprocesy”. The path's singular spelling does not block a
collection. A later `/audioprocesy` rename is optional and would need a permanent
redirect from the old category URL, not redirects from individual product pages.

Add visible navigation for **Audioprocesy**, **Bajki audio**, and **Współpraca 1:1**.
The stories link can target the proposed shop section; a dedicated `/bajki` landing
is justified later if it needs its own editorial content. Do not introduce an
extra category page solely for URL symmetry. Keep `/en` equivalents and link each
product's language alternative to that same product.

A category and a product should have different layouts. The category helps a
visitor choose; the product page helps them understand and buy the selected item.
Their product names, prices, availability and access terms must agree.

## Executive summary and health score

**Eight findings: P0: 0 · P1: 2 · P2: 4 · P3: 2.** The two major findings are the
single-product collection selector and the locally contradictory program offer.
The other priorities are stories discovery, grouping the catalogue, and moving
useful sales-page behavior into reusable individual product details.

| Dimension | Score | Key finding |
| --- | --- | --- |
| Accessibility | 3/4 | Native disclosure works with Enter; named purchase controls and focus styling. Back link below the project's 44px target. |
| Performance | 3/4 | Native media with `preload="none"`, fixed aspect ratio, self-hosted fonts. Production loading performance was not profiled. |
| Responsive design | 3/4 | Both target pages fit 390px without horizontal overflow; 1440px desktop inspected. Missing-trailer variant puts a large decorative tile before the product on mobile. |
| Theming | 4/4 | Consistent warm dark palette and shared typography; no new surface-level token defects verified. |
| Implementation integrity | 1/4 | Collection assumes one item; category/product roles overlap; local deliverable contradicts its configured completeness. |
| **Total** | **14/20** | **Good technical baseline; catalogue architecture needs correction before expansion.** |

The score is unchanged because the code is unchanged; the new requirement changes
which architecture should be kept. It is not an accessibility certification or a
production performance result.

## Detailed findings

### 1. [P1] The category entry point silently excludes every additional audioprocess

- **Location:** `app/controllers/audio_processes_controller.rb:3`;
  `app/views/audio_processes/show.html.erb:9`.
- **Category:** Implementation integrity.
- **Evidence:** `Product.published.audio_process.includes(:audio_chapters).ordered.first`.
  The view accepts one `@product`, displays a buy action and its full program,
  and has no product-detail links in its main content.
- **Impact:** future programs will not appear through the main Audioproces entry
  point; catalogue ordering can silently change which program it sells.
- **Recommendation:** load the published collection and render a concise card for
  every program. Each card links to its `/products/:id`. If one product is featured,
  feature it deliberately and still show the rest. Preserve a collection layout
  with one item so the second addition does not require another restructuring.
- **Suggested command:** `$impeccable harden`.

### 2. [P1] Product 2 promises 24 recordings but is configured as a complete one-chapter program

- **Location:** local Product 2; `app/models/product.rb:132` and `:169`;
  `app/views/products/_chapter_outline.html.erb:1`.
- **Category:** Implementation integrity.
- **Evidence:** current inclusions promise 24 recordings. A fresh read-only local
  query returned expected count 1, actual count 1, ready count 1, complete true,
  length “3 min”. Both pages list “Wstęp” at 2:52 and enable purchase at 497,00 PLN.
- **Impact:** the buyer cannot reconcile the promised content with the visible
  program. Route changes will not fix this underlying contradiction.
- **Recommendation:** confirm the intended deliverable and align expected chapter
  count, files and copy. If 24 is correct, the declared count should reflect that;
  existing readiness logic can suppress purchases until complete. Identify any
  partial outline as a preview and avoid presenting partial duration as total length.
  Apply the same truth rules to every future product.
- **Suggested command:** `$impeccable harden` after product truth is confirmed.
- **Scope:** verified locally only; production was not queried. Local published
  counts currently contain one audioprocess and no bajki, so future catalogue
  behavior was assessed from code rather than fabricated records.

### 3. [P2] Bajki have no visible primary-navigation destination

- **Location:** `app/helpers/navigation_helper.rb:16`;
  `config/locales/pl.yml:254`; `app/views/shared/_footer.html.erb:26`.
- **Category:** Implementation integrity / information architecture.
- **Evidence:** primary navigation contains singular “Audioproces” and 1:1. The
  general shop is available in the footer, but stories have no direct category entry.
- **Impact:** as stories are published, visitors have to discover a footer shop
  link or arrive via a direct product URL. The navigation understates the offer.
- **Recommendation:** expose plural Audioprocesy and Bajki audio as distinct
  destinations, keeping 1:1 visible. Start with a link to a real stories section in
  `/products`; do not add an empty category destination before content exists.
- **Suggested command:** `$impeccable clarify`.

### 4. [P2] The general catalogue does not separate the two audio audiences

- **Location:** `app/controllers/products_controller.rb:11`;
  `app/views/products/index.html.erb:34`; `app/views/products/_card.html.erb:24`.
- **Category:** Implementation integrity / responsive information structure.
- **Evidence:** all published audio products enter one ordered grid. Kind is a
  label on each card, not a collection section. Cards repeat the full description
  and have no compact suitability or duration summary.
- **Impact:** parents seeking guidance and parents seeking a bedtime story must
  scan the same mixed sequence. Long descriptions compound mobile reading load
  as more products are added.
- **Recommendation:** use labelled Audioprocesy and Bajki audio sections with
  stable anchors and concise cards. Existing kind labels and native links are a
  useful foundation. Use real product metadata; introduce age/suitability fields
  only when the owner can provide those facts. A small catalogue does not yet
  require search, advanced filters or pagination.
- **Suggested command:** `$impeccable layout`.

### 5. [P2] The reusable detail page loses the better program-reading structure

- **Location:** `app/views/products/show.html.erb:94`, compared with
  `app/views/audio_processes/show.html.erb:38`;
  `app/helpers/products_helper.rb:3`; `config/content_blocks.yml:766`.
- **Category:** Implementation integrity / responsive reading.
- **Evidence:** the individual page uses “O tym nagraniu” for a multi-recording
  program and renders all rich inclusions expanded. The landing supplies “Dla kogo”
  and a short introduction plus native disclosure. Format/access facts appear
  together near purchase only on the individual detail page.
- **Impact:** choosing `/products/:id` without improving its template discards useful
  suitability framing and creates a long text wall for each future program.
- **Recommendation:** transfer the reusable suitability and disclosure patterns to
  audio-process product details. Retain the actual product-name H1, price and access
  facts. Keep content in that Product record and editable labels in the CMS. Story
  details can remain shorter with their sample and description. Do not copy the
  current single-product landing's full text into every collection listing.
- **Suggested command:** `$impeccable distill`.

### 6. [P2] Trailer availability changes mobile product priority

- **Location:** `app/views/products/show.html.erb:19`.
- **Category:** Responsive design / implementation integrity.
- **Evidence:** if a trailer is present, the product identity and purchase column
  comes first on mobile. If absent, an aspect-square decorative emoji tile appears
  before that column. This branch applies to stories and programs without trailers.
- **Impact:** the products most likely to lack a trailer consume roughly a screen
  width of vertical space before the visitor can read the product name. An optional
  asset changes reading priority instead of merely adding or removing media.
- **Recommendation:** keep name, short benefit, price and action early in every
  product variant. Treat a trailer or story sample as optional media; keep large
  fallback decoration out of the first mobile position. Build type-aware sections
  within one shared product-page system, not a separate bespoke page per title.
- **Suggested command:** `$impeccable adapt`.
- **Verification limit:** this fallback is established from source; no unpublished
  story or second program was created to simulate it.

### 7. [P3] The trailer has no meaningful initial image

- **Location:** `app/views/products/_trailer.html.erb:4`.
- **Category:** Implementation integrity / presentation.
- **Evidence:** the shared native video has no poster and initially displays an
  empty dark media rectangle. `preload="none"` is appropriate and should remain.
- **Impact:** prominent space provides little product recognition before playback.
- **Recommendation:** allow a real, owner-approved, locally served product poster
  when available. Do not require autoplay or preload every product trailer in a grid.
- **Suggested command:** `$impeccable polish`.

### 8. [P3] The product back link is smaller than the project touch target

- **Location:** `app/views/products/show.html.erb:14`.
- **Category:** Accessibility / responsive design.
- **Evidence:** measured height 35.6px; the purchase button measures 53.6px.
- **Impact:** returning to the collection is less forgiving for one-handed use.
- **Standard:** misses the project's 44px target; not by itself a demonstrated
  WCAG 2.1 AA failure.
- **Recommendation:** use a 44px minimum and give the back link category context.
  Keep a way to browse all offers without relying on browser history or session state.
- **Suggested command:** `$impeccable adapt`.

## Shared system, different page responsibilities

| Element | Collection | Audioprocess detail | Bajka detail |
| --- | --- | --- | --- |
| Main heading | Category name | Exact product name | Exact product name |
| Opening | Short category explanation | Who it helps and what it covers | What the story is and whom it suits, where known |
| Media | Compact visual; no wall of players | Optional trailer | Optional public sample |
| Content | Concise cards for every listed item | Overview, topics disclosure, truthful chapter outline | Description and relevant listening details |
| Commerce | Same price/availability truth; clear detail link | Shared purchase/owned/pending/unavailable states | Same shared states |
| Delivery | Brief consistent summary if useful | Format, access, trustworthy total duration/count | Format, access, trustworthy duration |

Do not add claims or product-specific fields without owner-supplied facts. Shared
format/access text can remain shared while those terms genuinely apply to all
products. Related-item ordering may later favor the same kind, but it is not a
verified defect: the current heading promises only “Inne materiały”.

## Patterns and positive findings

The systemic gap is that product kind exists in the data but is not fully expressed
in discovery. Meanwhile, category editorial content and one product's sales content
are interleaved. Separating those responsibilities resolves the apparent layout
conflict without forcing every page to look identical.

Keep the two-kind Product model, per-ID detail lookup, shared price lookup, cart
partials and native playback controls. The underlying model does not need separate
product tables for programs and stories. Preserve the warm palette, self-hosted
fonts, visible focus rules and native disclosure. At 390px both target pages fit
without horizontal overflow; disclosure opens with Enter and the purchase target
is about 54px high. The category disclosure itself meets 44px. Existing sampled
palette ratios from the earlier pass remain applicable because the audited styles
are unchanged; body and muted text on the warm dark surfaces clear 4.5:1.

The bundled detector was rerun on both targets and the catalogue/card templates.
It returned three advisory font-size findings: 110px decorative emoji on the two
pages and 44px emoji on catalogue cards. All are in `aria-hidden` decoration, not
reading typography, so none is reported as a verified type-ramp defect.

## Recommended actions

1. **[P1] `$impeccable harden`** — make `/audioproces` a true collection, keep
   per-product URLs, and reconcile the declared/actual deliverable for product 2.
2. **[P2] `$impeccable clarify`** — establish plural navigation labels and a clear
   stories entry point; keep shared facts consistent.
3. **[P2] `$impeccable layout`** — group the existing shop by kind with concise
   cards and working section anchors.
4. **[P2] `$impeccable distill`** — move suitability and progressive disclosure into
   the reusable audioprocess detail variant.
5. **[P2/P3] `$impeccable adapt`** — keep product identity before fallback media
   on mobile and enlarge the back link.
6. **[P3] `$impeccable polish`** — finish real media presentation and check the
   final collection/detail layouts together.

You can ask me to run these one at a time, all at once, or in any order you prefer.
Re-run `$impeccable audit` after fixes to reassess the result.

## Verification boundaries

Live local pages and source were rechecked; mobile width 390px and desktop width
1440px were inspected on the two targets. `/products` was inspected to verify the
surrounding discovery flow. Product metadata was queried read-only. No files,
prices, products, purchase state or publication state were changed. Only this audit
report was updated. No production performance trace, checkout, paid playback,
trailer-content/caption review, 200% text scaling or synthetic multi-product browser
fixture was run. Future multi-product limitations are tied to the explicit source
branches above, not claimed as observations of records that do not yet exist.
