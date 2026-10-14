# Products and Bajki audio: UX brief and audit

14 October 2026. Shaped with Impeccable. **Status: implemented locally; verification recorded below.**
The approved brief has been implemented. See
`docs/products-and-stories-verification.md` for tests and audit evidence.
Unrelated uncommitted changes and plan-compatible changes were preserved;
conflicting category routes, navigation and card behavior were updated selectively.

The route decisions and samples on `/stories` cards are confirmed by the user.
The user amended the approved plan to use English route names in both languages:
`/audio-processes` for programs and `/stories` for stories. The user confirmed
that production has a clean database and legacy URL support is unnecessary.
Use the English routes and anchors directly, with no redirects, route aliases,
old submission endpoints or Polish fragment aliases.
The user approved the complete brief, including the collection routes,
shared product-detail URLs and story-card samples.
The audit below records the inspected baseline. The implementation verification
is a separate report; historical findings remain here for context.

The user confirmed that `/products` should remain the all-offers shop and that
`/stories` should become a stories collection. **Both audioprocesy and bajki already
have individual `/products/:id` pages. Preserve that shared product-detail route
for both kinds.** A category route lists products; it does not replace their pages.

## Confirmed route structure

| Route | Job | Links onward |
| --- | --- | --- |
| `/products` | Sklep: overview of every offer, grouped by kind | Category destinations and individual products |
| `/audio-processes` | All published audioprocesy for parents | Each program's `/products/:id` |
| `/stories` | All published audio stories for children | Each story's `/products/:id` |
| `/products/:id` | One audioprocess or one story: explanation, media, price and purchase | Its category, dashboard or cart as appropriate |
| `/packages` | Consultation offers and booking | Existing booking flow |
| `/testimonials/:token` | Token-specific invitation to submit a testimonial | Existing submission action |

Keep matching `/en` routes. URL segments use English independently of interface
language: “Audioprocesy” and “Bajki audio” remain the Polish labels. Replace the
Polish path declarations with their English names. IDs, cart operations,
playback endpoints, ownership checks and checkout keep their existing responsibilities.

## English route review

`config/routes.rb` currently declares two Polish path segments: `audioproces`
and `opinia`. The prior plan also proposed Polish collection names. Other
declared routes already use English and keep their current paths.

| Current or previously planned address | Replacement address |
| --- | --- |
| `/audioproces` (existing) | `/audio-processes` |
| `/audioprocesy` (previous plan) | `/audio-processes` |
| `/bajki` (previous plan) | `/stories` |
| `/opinia/:token` (existing) | `/testimonials/:token` |
| `/products#audioprocesy` | `/products#audio-processes` |
| `/products#bajki` | `/products#stories` |
| `/products#wspolpraca` | `/products#packages` |

Apply the same mappings under `/en`. No `/pl` prefix is introduced: the bare
English-named path still renders Polish by default, and `/en` selects English.
Renaming `/opinia` changes only the URL, not token lookup, submission fields,
rate limits, moderation or publication consent. Keep the existing Rails helper
semantics; invitation links, forms and normal success redirects use the English
path. Only the English testimonial endpoint handles reads and updates. Admin
and integration paths already use English.

## Shaped UX brief

### 1. Job, audience and outcome

An exhausted parent arrives on a phone, often from a social link, looking either
for guidance for themselves or a story to hear with their child. Each category
must make that distinction obvious without asking them to interpret the entire
catalogue. Visitor mode: **Persuade**, across the shop, collections and sales pages.

On `/stories`, success is choosing a recording after reading a short description
and, where available, hearing its actual 30-second sample. The visitor can add it
directly to the cart or open its individual page for the full explanation. Samples
are real product evidence; no invented age bands, outcomes or testimonials are
needed to make the page persuasive.

### 2. Selected direction and visual authority

Extend the established world in `DESIGN.md`: warm dark surfaces, cream/tan reading
text, amber principal actions, Baloo 2 names, Quicksand explanations and generous
controls. Use the existing collection/grid/card vocabulary. The focal moment is
hearing the story, rather than encountering a large decorative hero.

Build a compact listening collection. Keep the heading and introduction short,
bring the first recording into view early, and place the sample inside the card
it describes. Use ordinary native audio controls; the sample is secondary to the
existing purchase action. No new player visual system or artwork is required.

### 3. Page hierarchy and responsive layout

| Surface | Reading and action sequence |
| --- | --- |
| `/stories` | H1 “Bajki audio” → short owner-editable introduction → story cards → shared audio access facts → quiet “Sklep” link |
| `/products` | H1 “Sklep” and brief introduction → labelled local category jumps → audio groups with collection links → shared audio delivery facts → Współpraca 1:1 |
| `/audio-processes` | Existing program collection at its plural URL; cards retain their individual `/products/:id` links |
| `/products/:id` | Compact category navigation → existing product identity, media, price and purchase flow → kind-specific details → same-kind related products |

In the shop, keep the order Audioprocesy → Bajki audio → Współpraca 1:1.
Category headers include “Zobacz wszystkie audioprocesy” and “Zobacz wszystkie
bajki”, pointing outward to the collections. Keep the 1:1 cards and booking links.
Audio delivery facts must remain explicitly scoped to recordings, not packages.
Place those shared facts after the audio groups, before 1:1, rather than above
the initial category choices. Account/cart utilities stay compact and subordinate.

On phones, cards form a single readable column; longer names and labels wrap.
On wider screens, inherit the existing bounded grid and one/two-product caps.
Allow cards with a sample to grow naturally; never reserve an empty player slot
on cards without one. Group price and commerce controls near the bottom. Keep
the first card visible within a normal phone opening when content length allows;
do not achieve that by shrinking text or hiding useful content.

### 4. Story-card interaction

Each `/stories` card contains, in order: linked H2 name and existing icon, concise
description, duration when populated, optional labelled sample, current Paddle
price and commerce state, then “Zobacz szczegóły”. Product names and details links
both open that story's existing `/products/:id` page. In the grouped shop, names
remain H3 under their H2 categories.

The user selected **samples directly on `/stories` cards**. Render a named native
audio control only when the existing preview-availability check passes and the
visitor does not already own the story. Use the current signed preview endpoint,
`preload="none"`, and the established media-error/retry copy. No sign-in is needed
for a sample. The full recording remains in the buyer's dashboard.

Only one sample plays at a time: starting another pauses the first without
resetting its position or moving focus. Navigating away stops playback; returning
does not resume it automatically. Adding to the cart updates only the commerce
region, preserving the player and its position. A playback failure reveals a
local status message and retry control; details and cart actions remain usable.

Keep samples on individual story pages as well. Limit the new card-player variant
to `/stories`; shop and program cards stay concise. Optional story duration can be
shared across catalogue cards. Do not add program trailers to this change.

### 5. Navigation continuity and scope

Desktop/mobile navigation and the footer use `/audio-processes`, `/stories` and
`/packages` as category destinations. Local shop jumps use `#audio-processes`,
`#stories` and `#packages`, remain anchors, and are
labelled as navigation within the shop, not filters or tabs.

Every individual product uses its kind to select the return destination:
“Wróć do audioprocesów” → `/audio-processes`, or “Wróć do bajek audio” → `/stories`.
Include a secondary “Sklep” link so mixed-catalogue discovery stays available.
These are stable category links; do not depend on browser history or referrers.
Show up to three other published products of the same kind, in catalogue order,
under an editable kind-specific heading. Hide that group when none exist.

Implementation covers English canonical collection URLs, the testimonial URL
migration, the new collection, its CMS copy, navigation links, shop
hierarchy and category continuity for **both** product kinds. Preserve the common
detail template, kind-specific partials, commerce rules, playback authorization
and package booking. Renaming the program collection and updating existing links
to it, including the home-page program link, are in scope. Individual product URLs,
brand tokens, home-page composition and catalogue publication data are outside scope. No search, filters,
bundles, subscription model or wider redesign is required.

### 6. Content ranges and material states

| State | Required behavior |
| --- | --- |
| Zero published stories | H1, short introduction, editable honest empty message and shop link; omit cards and purchase controls. Do not invent a release date. |
| One or two stories | Retain existing small-collection grid caps; do not stretch a singleton across the desktop width. |
| Several stories | Render every published story in configured order, with natural wrapping and no silent truncation of the collection. |
| Missing duration or sample | Omit the absent information; retain description, details and truthful commerce state. |
| Sample loading or failure | Native loading feedback; local accessible error/retry on failure. Playback does not block browsing or buying. |
| Price unavailable | Existing unavailable copy and contact path; suppress new purchase actions. |
| In cart | Existing remove action and added confirmation; preserve player state during the update. |
| Already owned | Existing dashboard listening action; omit the smaller sample offer. |
| Payment pending | Existing pending-payment/dashboard path; prevent another purchase. |
| Unpublished story | Excluded from collection and recommendations; existing direct-detail behavior remains. |

### 7. Constraints, content ownership and acceptance

Use Rails/Hotwire and the current shared grid, card, commerce, media recovery and
delivery components. A new story-player variant must not create a second source
of prices, availability or cart state. No third-party assets or scripts are added
for passive reading; media remains request-driven. Preserve the established
reduced-motion behavior and visible keyboard focus.

Add a dedicated stories-collection CMS entry for title, introduction and empty
message. New return-link, collection-link and related-heading copy must be
editable through the established content-block/locale conventions. Reuse existing
preview/error/retry, card-action and delivery facts instead of duplicating them.
Actual story text, durations and preview recordings come from product records.

Polish is canonical; every new route/link has its `/en` equivalent. Language
switching stays on the same collection or product. Existing Polish content fallback
is intentional. Public controls must have accessible names, at least the project's
44px custom-control targets, and support keyboard use. Native media controls must
remain usable at narrow widths and enlarged text. WCAG 2.1 AA remains the project
baseline; check the actual supplied media and text alternatives during implementation.

Acceptance: links and forms use the English routes directly in both languages.
The removed Polish route names have no aliases or redirects. Collection/shop
links resolve to the same product IDs; no program
appears in `/stories`; published ordering holds; zero/one/many stories and all states
above work in Polish/English; mobile navigation closes on selection;
media and keyboard focus survive cart updates; phone/desktop
layouts and enlarged text show no overflow. No commerce or playback policy changes.

`/testimonials/:token` retains token validation, success and validation-error
behavior. Local category links use only the English fragments, landing below the
sticky navbar and accepting focus. Test these in both languages.

No unresolved route or sample-placement decision remains. The remaining content
dependency is the owner's actual story catalogue; implement empty and populated
states with meaningful fixtures without publishing invented products.

## Implementation integrity verdict: pass, with navigation gaps

The current implementation expresses the product's two audio kinds coherently:
`Product.kind`, kind-specific detail partials, shared commerce controls and separate
shop sections. `AudioProcessesController#show` now loads the whole collection;
earlier findings about selecting only the first program no longer apply.

The Impeccable detector returned `[]` for the shop index, shared card/grid,
audioprocess collection, navbar and footer. The findings below are verified route
and layout behavior, not detector warnings or claims of broken commerce.

## Audit summary

| Dimension | Score | Evidence and limits |
| --- | --- | --- |
| Accessibility | 3/4 | Logical shop H1/H2/H3 hierarchy, named regions, visible focus styles, 44px category links; full assistive-technology and contrast testing not performed. |
| Performance | 3/4 | Server-rendered shared catalogue, self-hosted fonts, product media uses `preload="none"`; production loading and large-catalogue performance not profiled. |
| Responsive design | 4/4 | Shop fits 1440px and 390px without horizontal overflow; category links wrap; mobile menu closes and exposes the anchor heading below the sticky navbar. Scoped to the available local content. |
| Theming | 4/4 | Consistent warm dark tokens and existing typography. A separate light theme is deliberately unsupported. |
| Implementation integrity | 3/4 | Shared product model and components are coherent; collection identity and return navigation need alignment. |
| **Total** | **17/20 — Good** | A sound implementation with discovery improvements to plan. |

Four findings: P0: 0, P1: 0, P2: 4, P3: 0. This is a scoped local audit,
not accessibility certification or a production performance assessment. The local
shop has one published program and no published stories. Existing request/system
specs cover additional records and enlarged text; those specs were read, not run
again for this planning task.

## Findings

### [P2] Stories lack an independent collection destination

- Location: `app/helpers/navigation_helper.rb:19`,
  `app/views/shared/_footer.html.erb:27`, `config/routes.rb:30`.
- Category: implementation integrity / information architecture.
- Evidence: Bajki audio points to `/products#bajki`; Audioprocesy points to
  `/audioproces`. The stories destination shares the shop's title and opening
  content. The hash identifies a section, not a separately rendered page.
- Impact: visitors arriving specifically for stories enter a mixed catalogue;
  there is no stories-specific introduction or page title at a standalone address.
- Recommendation: add `/stories` and `/en/stories`, with only published bedtime stories.
  Update desktop/mobile navigation and footer together.
- Standard: no verified WCAG violation; this is a discovery issue.
- Suggested command: `$impeccable shape`.

### [P2] The shop's opening delays browsing on a phone

- Location: `app/views/products/index.html.erb:5`–`:33`.
- Category: responsive information hierarchy.
- Evidence: at 390 × 844, the first card begins near the bottom of the viewport;
  the stories section starts at approximately 1297px before anchor navigation.
  The opening stacks introduction, returning-buyer copy, cart, delivery facts and
  category links before the catalogue.
- Impact: visitors with limited reading capacity encounter several supporting
  elements before they can inspect an offer. This is extra reading and scrolling,
  not overflow or a broken mobile menu.
- Recommendation: put category choices immediately after the short shop intro.
  Keep account/cart utilities compact. Present audio delivery facts closer to the
  audio sections. Add explicit collection links beside section introductions;
  keep local jump links clearly labelled as jumps within the shop.
- Standard: no verified WCAG violation.
- Suggested command: `$impeccable layout`.

### [P2] Product pages return every visitor to the mixed shop

- Location: `app/views/products/show.html.erb:10`.
- Category: implementation integrity / navigation continuity.
- Evidence: the back link is always `products_path`, irrespective of product kind.
- Impact: someone choosing a program through `/audioproces` loses the category
  journey. The same would happen to someone browsing stories through `/stories`.
- Recommendation: use deterministic category navigation based on the product kind:
  “Wróć do audioprocesów” or “Wróć do bajek audio”. Provide Sklep as a secondary
  breadcrumb/link. Avoid dependence on referrers or a newly invented detail route.
- Standard: no verified WCAG violation.
- Suggested command: `$impeccable clarify`.

### [P2] Related products ignore the visitor's selected audio kind

- Location: `app/controllers/products_controller.rb:20`.
- Category: implementation integrity / discovery relevance.
- Evidence: `@also` selects the first three other published products in global
  catalogue order, without filtering by kind.
- Impact: as the catalogue grows, a story page can recommend programs before
  other stories, and a program page can recommend stories before other programs.
- Recommendation: prioritize other products of the same kind. Omit the related
  group if none exist; cross-category discovery can remain in the navigation/shop.
- Standard: no verified WCAG violation. Future mixed-catalogue behavior is inferred
  from the current query, not observed with invented local products.
- Suggested command: `$impeccable harden`.

## Patterns and strengths to preserve

The repeated gap is category continuity: collection destination, product return
link and related products should agree about which kind the visitor is exploring.
Keep shared product data and commerce behavior rather than creating a second
story-specific product implementation.

Useful foundations already exist: independent grid caps for small collections,
short card descriptions with full detail copy preserved, sensible publication
guards, honest unavailable/owned/payment states, editable empty-state copy,
shared access facts, and focused anchor destinations. Mobile selection of Bajki
audio closed the menu; its heading landed at 96px, below the navbar ending at 64px.

## Shop and category links

The program collection is `/audio-processes`. Update navigation, footer, shop collection links,
product return links and the existing home-page program link to the plural URL.
Language alternatives resolve directly to the plural collection in each language.
The singular references in the audit above describe the inspected baseline.
Individual audioprocess and story URLs remain `/products/:id`.

Keep the grouped catalogue. Its anchors become `#audio-processes`,
`#stories` and `#packages`. Add “Zobacz wszystkie bajki” linking
to `/stories` and an equivalent program
collection link. Primary category navigation goes to the dedicated routes; local
shop navigation continues to scroll within the catalogue.

## Implementation order and acceptance

1. Rename the program collection route to `/audio-processes` and the testimonial
   invitation path to `/testimonials/:token`. Replace the Polish route declarations.
   Add the localized `/stories` collection route, controller query and shared-grid
   rendering with optional card samples, single-active playback and local recovery.
   Add editable collection copy and a distinct page title.
2. Update desktop/mobile navbar, footer and existing category links to
   `/audio-processes` and `/stories`. Audit existing links:
   shop links and section IDs use only English anchors.
   Links promising the stories collection move to `/stories`.
3. Tighten the shop opening and add outward collection links while retaining all
   offers.
4. Make detail breadcrumbs/return links and related products category-aware for
   **both** audioprocesy and stories. Keep their common product-detail template,
   kind-specific partials and existing endpoints.
5. Verify English routes, testimonial submissions and English fragments in
   both languages, published-kind filtering,
   ordering, zero/one/many stories, English route
   switching, identical product URLs across collection/shop, unavailable price,
   purchase states and optional media. Update existing navigation specs to the
   English routes and anchors. Check phone/desktop layout, keyboard use,
   enlarged text and media recovery with meaningful fixtures.

Recommended implementation command sequence:
`$impeccable layout`, `$impeccable clarify`, `$impeccable harden`, then
`$impeccable polish`. Re-run `$impeccable audit` after implementation. These can
be run separately or together. This brief records the approved scope and behavior. Implementation verification
is recorded separately; the findings above describe the earlier baseline.
