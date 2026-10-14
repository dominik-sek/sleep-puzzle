# Products and audio collections: post-implementation audit

14 October 2026. Targets: `/products`, `/audio-processes`, `/stories`, with
shared product-detail and navigation components inspected for continuity.
Audit only: no application fixes or catalogue publication.

## Adapt follow-up: shop target resolved

The `/stories` shop link now declares both `min-h-11` and `min-w-11`.
Live browser measurements returned **44px width × 44px height** for “Sklep”
and “Shop” at 320px, 390px and 1440px viewport widths, with no horizontal
overflow. Keyboard focus remains visible.

`spec/system/stories_spec.rb` now checks the rendered link's **width and height**
in both languages, for both empty and populated collections, at all three widths.
The stories system suite passed: **12 examples, 0 failures**, including four new
regression examples covering those dimensions and states. The targeted detector
returned `[]`, and the source diff has no whitespace errors.

Finding 1 below is resolved. The original audit score and measurements record the
pre-fix baseline; finding 2 is resolved by the optimization follow-up below.

## Optimize follow-up: ownership queries batched

Catalogue cards and story samples now share request-local paid/pending ID sets in
`ProductsHelper`. The sets are scoped to the products rendered by the collection
and loaded through the existing `purchased_products` and `awaiting_products`
associations. Fully refunded paid items remain excluded; a separate active paid
purchase still grants access. Pending state keeps its existing precedence in the
commerce control. Anonymous and empty collections issue no ownership queries.

| Stories rendered | Ownership queries before | Ownership queries after |
| --- | --- | --- |
| 1 | 2 | 2 |
| 10 | 20 | 2 |

The same one-versus-ten regression checks verify **two queries** on `/products`
and `/audio-processes`, including the mixed shop's two grids. The repeated
`/stories` measurement also reduced total uncached SELECTs from **28 to 10** for
ten stories. These are local SQL counts, not a production latency measurement;
schema introspection and Rails query-cache hits are excluded.

The cache belongs to the view context for one request. Single-product details and
cart-stream rendering fall back to fresh model checks. Cart mutation, checkout
and paid streaming authorization retain their existing model/controller rules;
no cache was added to `User`, `Cart` or the paid stream gate.

New regression coverage checks both product kinds, paid/pending/canceled/failed
orders, fully refunded items, another buyer's purchases, an active purchase after
a refunded purchase, overlapping paid/pending states, sample visibility, anonymous
and empty collections, and refreshed page/cart behavior after payment/refund
changes. The full targeted run had **161 examples: 160 passed and one existing
Polish anchor-navigation timing failure**. Its six-example navigation group then
passed in isolation. All ownership, access, cart, checkout and playback checks
passed. RuboCop reported no offenses in the helper and new request specs, the
targeted detector returned `[]`, and the source diff check passed.

Logs: `/private/tmp/sleep-puzzle-ownership-tests.log` and
`/private/tmp/sleep-puzzle-ownership-navigation-confirmation.log`. Testing used an
isolated local database. The original score below remains the pre-fix audit
baseline; both actionable findings are now resolved.

## Polish follow-up: controls and states confirmed

The post-fix verification passed: **27 examples, 0 failures**, covering ownership
request regressions, stories, shop collections and two temporary visual/state
diagnostics. No further application changes were needed.

Populated collections were inspected using isolated fixtures in Polish and
English at 390px, 768px and 1440px; the persistent stories regressions also cover
320px. Phone and desktop captures of the shop, programs and stories were reviewed.
Available, in-cart, owned, pending-payment, unavailable-price and incomplete-program
states retained their intended actions. The stories subtitle measured **19px**;
the shop link measured at least **44px wide × 44px high** in both languages.
Commerce actions and media retry targets also passed both dimension checks.
No horizontal overflow was found.

Keyboard cart additions and removals retained focus on the replacement control
and announced success. A deliberately failing sample exposed local recovery and
a usable retry action while details and cart actions remained available. The
persistent playback tests also passed with a locally served playable WAV. Paid
and pending collection checks stayed at two queries, with access and cart behavior
covered by the request regressions.

The live local catalogue's phone navigation completed shop → programs → product
detail → programs, then stories → shop. Its empty stories state remained usable;
the checked browser reported no console errors. The targeted detector returned
`[]`, and the source diff check passed.

Evidence is under `/private/tmp/sleep-puzzle-catalogue-polish`: `tests.log`,
`stories-pl-390.png`, `stories-pl-1440.png`, English equivalents, phone/desktop
media-recovery captures, and shop/program captures. Names, prices and media in
these populated captures are synthetic fixtures, not published catalogue content.
The dedicated test database was removed after verification.

This confirms the scoped controls and states in local Chrome and the in-app
browser; physical-device behavior and production recordings/CDN delivery were
not measured. Existing `DESIGN.md` catalogue prose still names the retired Polish
anchors and an older section gap; that documentation drift was left untouched.
The original audit score below remains a historical pre-fix baseline.

## Implementation integrity verdict: pass

The implementation expresses the approved product structure coherently. The
mixed shop groups programs, stories and packages; each audio collection selects
its own published kind and links to the same `/products/:id` detail pages.
Category return links and related products follow the product kind. Navigation,
collection links and shop fragments use the English names, without Polish aliases
or redirects. Polish labels and `/en` language variants remain available.

Prices, purchase eligibility, ownership, pending payments and sample playback use
the existing shared components. Native sample players live on story cards and
detail pages, outside the Turbo-replaced commerce region. The targeted Impeccable
detector returned `[]`; no detector findings required interpretation or dismissal.

## Executive summary and health score

**17/20 — Good. Two actionable findings: P0: 0, P1: 0, P2: 2, P3: 0.**
The remaining issues are a narrow shop-return target on `/stories` and per-product
ownership queries on signed-in catalogue visits. No blocking task failure or
verified WCAG AA violation was found within the inspected scope.

| Dimension | Score | Finding or evidence |
| --- | --- | --- |
| Accessibility | 3/4 | Named controls, semantic headings, keyboard focus and local playback status work. Actual spoken-media text alternatives and full assistive-technology behavior were not verified. |
| Performance | 3/4 | Deferred media, shared components and self-hosted assets; two uncached ownership queries per story for signed-in visitors. |
| Responsive design | 3/4 | Phone/desktop layouts and enlarged text hold; the Polish stories-to-shop link measures approximately 38 × 44px. |
| Theming | 4/4 | Coherent warm dark tokens, self-hosted type and compliant measured text contrast. A light theme is outside the established design. |
| Implementation integrity | 4/4 | English routes, category filtering, shared details and truthful commerce/media states match the brief. |
| **Total** | **17/20** | **Good; address the two minor findings.** |

## Detailed findings

### 1. [P2 — resolved] The stories-to-shop link misses the project's target width

- **Location:** `app/views/stories/index.html.erb:20`–`:21`.
- **Category:** Responsive design / accessibility.
- **Evidence:** the link declares `min-h-11` and vertical padding but has no
  minimum width or horizontal padding. On the live Polish page at 390px, “Sklep”
  measured **38.35px wide × 44px high**. It is the main onward action in the empty
  collection and also appears after a populated collection.
- **Impact:** its narrow hit area makes the way back to the shop harder to tap
  accurately with one hand. Height-only target checks did not catch this.
- **Standard:** the project's 44 × 44px custom-control requirement. This
  measurement alone does not establish a WCAG 2.1 AA violation.
- **Recommendation:** give the link a 44px minimum width or suitable horizontal
  padding, retaining its quiet visual treatment and visible focus outline.
  Verify both dimensions in Polish and English.
- **Suggested command:** `$impeccable adapt`.

### 2. [P2 — resolved] Signed-in collections perform ownership checks for every product

- **Location:** `app/models/user.rb:65`–`:73`;
  `app/views/products/_cart_button.html.erb:25` and `:46`;
  `app/views/products/_preview.html.erb:1`.
- **Category:** Performance.
- **Evidence:** `purchased?` and `awaiting_payment?` each call an association's
  `exists?` for the current product. An isolated request measurement of `/stories`
  with a signed-in visitor and previewable products returned:

  | Published stories | Uncached SELECTs in the request | Ownership SELECTs |
  | --- | --- | --- |
  | 1 | 9 | 2 |
  | 10 | 28 | 20 |

  Rails' query cache already removes the duplicate purchased check between a
  sample and its cart control; checks for different products still issue separate
  queries. The same cart-control calls are shared by the other catalogue pages.
- **Impact:** rendering a growing collection adds database round trips before
  the HTML can reach a returning buyer. No production latency threshold was
  measured; this is a demonstrated scaling problem, not a claimed outage.
- **Standard:** no WCAG violation; avoid per-record query growth in catalogue
  rendering.
- **Recommendation:** load paid-access and pending-payment product-ID sets once
  per request, scoped to the rendered collection, and use them consistently for
  sample visibility and commerce controls. Retain refunded-access rules and
  refresh the state on subsequent cart requests. Keep the underlying shared
  associations as the source of truth.
- **Suggested command:** `$impeccable optimize`.

## Verification evidence

- **123 examples, 0 failures** in a new targeted regression run: stories,
  products, collection grouping, programs, kind-specific details, navigation and
  product helpers, stories playback, shop navigation and product-detail layout,
  plus two temporary audit diagnostics for captures and query counts.
- Tests cover zero/one/two/many stories, publication filtering, configured order,
  shared product URLs, unavailable prices, owned/pending/in-cart states, both
  locales, keyboard cart focus, local media failure/retry and language continuity.
- Playback checks serve a real generated 30-second WAV locally. They verify no
  media request before play, one active sample, retained position/player identity
  across cart updates, pause on navigation and no automatic history resumption.
- Responsive tests include 320px, 390px and 1440px, long product names and 200%
  root text size for story controls. Product-detail enlarged-text checks also
  passed. Live shop and program layouts were inspected at 1440px and 390px;
  the live stories empty state was inspected at both widths.
- At 390px, the shop's first card begins at approximately **523px** and a
  populated stories collection's first card at **266px**. These are supplied
  fixture/content measurements, not guarantees for arbitrary owner copy.
- The shop stories jump focuses `#stories`; its heading landed at approximately
  **96px**, below the navbar ending at **64px**. Mobile category navigation closed
  its menu when opening `/stories`. English stories rendered `lang="en"` and
  kept its shop link under `/en`.
- Computed text/background pairs were measured on all three live pages,
  including visible navigation/footer text: 58 shop elements, 29 program-page
  elements and 26 stories-empty-state elements. No contrast failure was found;
  the lowest measured ratio was approximately **5.52:1**. This covers ordinary
  rendered text, not every native player control, interaction state or overlay.
- The detector scanned the three page views, shared grid/card/preview, navbar,
  footer and media-preview controller and returned `[]`.

Test logs and fixture captures are under `/private/tmp/sleep-puzzle-catalogue-audit`.
The first desktop program capture retained a scroll position; the capture-only
diagnostic was repeated with explicit top-of-page positioning. Fixture names,
prices and recordings are test data. No fixture products were published to the
application catalogue. Testing used a dedicated local audit database; application
database settings were not changed.

## Patterns, strengths and limits

The two findings identify different reusable improvements: check width as well
as height for custom targets, and share request-level purchase state across cards.
Neither requires changing the chosen route or page architecture.

Preserve the short catalogue descriptions, independently capped small grids,
named sample controls, native playback and local recovery, deliberate reduced
motion for navigation, focused shop anchors, kind-specific detail content and
truthful unavailable/incomplete/owned/payment states. Native players showing
`0:00 / 0:00` before media loads are consistent with `preload="none"`, not proof
of a broken recording. The empty stories collection is an intentional supported
state, not a failed collection query.

The application catalogue currently exposes one incomplete program and no
published stories. Populated stories were verified with isolated fixtures. The
owner's actual speech recordings, equivalent text alternatives, production CDN
delivery, production performance and a full assistive-technology audit remain
outside this result. No new defect is asserted solely from missing production
content. No visual-world or unrelated context-file repair was performed.

## Recommended actions

1. **[P2] `$impeccable adapt`**: make the `/stories` shop link at least 44 × 44px
   in both languages and include target width in verification.
2. **[P2] `$impeccable optimize`**: batch the catalogue's paid/pending ownership
   checks while preserving the existing access rules and cart behavior.
3. **`$impeccable polish`**: confirm the resulting controls and states on phone
   and desktop after those targeted fixes.

These can be run one at a time, together or in another preferred order.
Re-run `$impeccable audit` after fixes to reassess the score.
