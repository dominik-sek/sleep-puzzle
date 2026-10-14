# Audioproces route and interface audit

Audited 14 October 2026 against the local application after migrations were applied.
Scope: `/audioproces` and `/products/2`. Audit only; no application or content changes.

## Decision

Keep **`/audioproces` as the public sales URL for this featured product**, using its
landing-page structure. Bring across the useful purchase facts from the product
page. Redirect this product's `/products/2` HTML detail URL permanently to it, and
update catalogue links so visitors arrive directly at the chosen URL. Preserve
locale: `/en/products/2` should lead to `/en/audioproces`.

Keep the Product record as the source of product truth and checkout identity.
Keep product media routes, chapter streams, and other products' detail pages.
Resolve the featured product explicitly rather than choosing the first item in
catalogue order. This decision concerns one featured product; future audioprocesses
must retain distinct product destinations.

The landing is the stronger starting point because its introduction speaks to the
parent's situation, its section names explain suitability, and its long topic list
uses progressive disclosure. It already receives links from the home page,
navigation and footer. The generic page contributes useful delivery/access facts
and a stronger product-name hierarchy, but its catalogue presentation and fully
expanded copy are less suited to the mobile, social-led first visit in PRODUCT.md.

## Implementation integrity verdict: fail

Shared data and commerce partials are a good foundation, but there are two public
presentations of one offer with different information hierarchy and purchasing
facts. More seriously, current local content promises 24 recordings while the
product is configured as a complete one-chapter program.

The mechanical detector returned five advisories. Neither 110px decorative emoji
size is a reading-type violation: both containers are `aria-hidden`. The three
color advisories concern legacy form styling and calendar/package dialog
backdrops, not these pages. These are not verified defects in the audited surfaces.
The meaningful integrity failures below were established from rendered content,
controllers, templates and a read-only local product query.

## Audit health

| Dimension | Score | Evidence |
| --- | --- | --- |
| Accessibility | 3/4 | Named controls, landmarks, visible focus styles and keyboard-operable native disclosure; back link below project target size. |
| Performance | 3/4 | Trailer uses `preload="none"`, fixed aspect ratio and native controls; self-hosted fonts; no production performance trace collected. |
| Responsive design | 3/4 | Both layouts fit the checked 390px viewport without horizontal overflow; purchase targets approximately 54px high. Long opening copy remains costly on a phone. |
| Theming | 4/4 | Both surfaces use the same warm dark tokens and typography; no verified palette drift in scope. Dark is the intentional product appearance. |
| Implementation integrity | 1/4 | Divergent public destinations, unstable featured selection and contradiction between promised and configured program size. |
| **Total** | **14/20** | **Good technical baseline; significant product-integrity issues remain.** |

This is a scoped implementation assessment, not WCAG certification or a production
Core Web Vitals result. Checkout, paid playback, trailer contents/captions,
authenticated variants and 200% text scaling were not exercised. Source review
covered unavailable/owned/pending commerce branches; those were not all recreated
in the browser. Observations cover 390px mobile, an intermediate 776px rendering,
and 1440px desktop views. No purchases were made.

Seven findings: **P0: 0 · P1: 2 · P2: 3 · P3: 2**.

## Findings

### 1. [P1] The offer promises 24 recordings but sells a complete one-chapter program

- **Location:** local Product 2; `app/models/product.rb:132`,
  `app/models/product.rb:169`, `app/views/products/_chapter_outline.html.erb:1`.
- **Category:** Implementation integrity.
- **Evidence:** rendered inclusions say “24 krótkie, ale treściwe nagrania”.
  Read-only metadata returned `expected_chapter_count: 1`, `chapter_count: 1`,
  `ready_count: 1`, `program_complete: true`. The chapter is “Wstęp”, 2:52.
  Both pages offer purchase at 497,00 PLN. `/products/2` labels total length “3 min”.
- **Impact:** buyers cannot establish what they will receive. Consolidating routes
  alone would retain this contradiction. This is verified locally; production
  metadata was not queried.
- **Recommendation:** reconcile the owner's intended deliverable with the
  expected count and uploaded recordings before sale. If 24 is correct, declare
  that count and complete the files; the existing readiness gate can then suppress
  purchases while incomplete. Distinguish a preview outline from the full program
  and avoid presenting partial-file duration as a complete program duration.
- **Suggested command:** `$impeccable harden` after the owner confirms product truth.

### 2. [P1] Two sales destinations diverge, and the landing's product can change implicitly

- **Location:** `app/controllers/audio_processes_controller.rb:3`,
  `app/controllers/products_controller.rb:19`,
  `app/views/products/_card.html.erb:33`, `app/views/products/_also_card.html.erb:7`,
  `app/views/layouts/application.html.erb:1`.
- **Category:** Implementation integrity.
- **Evidence:** the landing selects `ordered.first`; the detail route finds its
  supplied ID. Home/navigation/footer use `/audioproces`, whereas catalogue links
  use `product_path`. Both render a sales page and neither declares a canonical
  URL. Catalogue reordering can change the landing's product.
- **Impact:** visitors arriving from different links see a different offer
  presentation; maintaining two templates perpetuates drift. Future ordering
  changes can silently replace the promoted product.
- **Recommendation:** adopt the route decision above, explicitly configure the
  featured product, redirect its old HTML destination, and update internal links.
  Keep language alternatives and canonical URLs consistent. Do not redirect every
  audio product or any playback endpoint to the featured landing.
- **Suggested command:** `$impeccable harden`.

### 3. [P2] The landing omits delivery and access facts shown on the product page

- **Location:** `app/views/audio_processes/show.html.erb:12`, compared with
  `app/views/products/show.html.erb:72`.
- **Category:** Implementation integrity.
- **Evidence:** only the generic page shows “Odsłuch online, bez pobierania” and
  “Bezterminowy, w Twoim koncie” together near the buy action. The landing includes
  lifetime access in its collapsed topic content, but omits the nearby facts row.
- **Impact:** visitors must infer how access works before paying, or discover the
  facts through a different route or long disclosure.
- **Recommendation:** put a concise, shared format/access summary by the landing's
  price and action. Display full-program duration only when it is truthful. Keep
  these facts editable and sourced once.
- **Suggested command:** `$impeccable clarify`.

### 4. [P2] The landing gives the category more emphasis than the actual product

- **Location:** `app/views/audio_processes/show.html.erb:6`.
- **Category:** Implementation integrity; visual hierarchy judgment.
- **Evidence:** the kicker and H1 both say “Audioproces”; the named product appears
  later as a smaller H2, after the landing introduction. A second explanatory
  paragraph follows the product name.
- **Impact:** a tired visitor reads two openings before establishing the exact
  item being offered. This adds mobile reading load without clarifying the choice.
- **Recommendation:** make the actual product name the H1, use “Audioproces” once
  as its category, and keep one concise opening benefit statement. Preserve the
  owner's remaining copy in the appropriate detail section; do not invent claims.
- **Suggested command:** `$impeccable distill`.

### 5. [P2] The generic detail page expands the full topic list into the main reading flow

- **Location:** `app/views/products/show.html.erb:107`, compared with
  `app/views/audio_processes/show.html.erb:45`.
- **Category:** Responsive design / Implementation integrity.
- **Evidence:** the same rich inclusions render directly on the generic page;
  the landing exposes short opening paragraphs and a native topic disclosure.
- **Impact:** the generic layout creates a long mobile reading obligation and
  a heavily unbalanced desktop text column. The copy is shared; its visibility
  and arrangement account for much of the perceived information difference.
- **Recommendation:** keep the landing's disclosure behavior in the consolidated
  page. Lead with a short overview and retain the full owner-written topics.
- **Suggested command:** `$impeccable distill`.

### 6. [P3] The trailer presents an empty media rectangle before playback

- **Location:** `app/views/products/_trailer.html.erb:4` (shared by both pages).
- **Category:** Implementation integrity; visual presentation.
- **Evidence:** `preload="none"` is correct for bandwidth, but there is no poster;
  the initial player is a blank dark gradient, prominently placed in each hero.
- **Impact:** prime space offers little recognition or reassurance until pressed.
  This is not evidence that playback itself is broken.
- **Recommendation:** use a real, locally served owner-approved poster if available,
  retaining the native controls, aspect ratio and no-preload behavior.
- **Suggested command:** `$impeccable polish`.

### 7. [P3] The product-page back link misses the project's 44px target

- **Location:** `app/views/products/show.html.erb:14`.
- **Category:** Accessibility / Responsive design.
- **Evidence:** measured height approximately 35.6px. The principal purchase
  controls are approximately 53.6px tall.
- **Impact:** a smaller target is less forgiving for one-handed phone use.
- **Standard:** misses the project's 44px target, not by itself a demonstrated
  WCAG 2.1 AA failure. Do not equate 44px with the AA requirement.
- **Recommendation:** use a 44px minimum if this back link is retained. The
  consolidated direct-arrival landing may not need this catalogue back affordance.
- **Suggested command:** `$impeccable adapt`.

## What to retain

- One warm dark visual system, Baloo 2 headings and Quicksand reading text.
- Strong primary-text contrast. Token calculations against ink/surface give
  cream 14.61:1 / 13.05:1, tan 9.90:1 / 8.85:1, taupe 5.52:1 / 4.93:1,
  and amber 6.69:1 / 5.98:1. These sampled token pairs clear 4.5:1.
- Large purchase targets, visible focus rules, named native media controls,
  semantic headings and a skip link into the main landmark.
- Native reading disclosure: Enter opens it and exposes the full topic list;
  the accessible label changes to “Zwiń listę tematów Co obejmuje”.
- Shared cart actions and product data. The divergence is primarily orchestration
  and presentation, not two separate copies of the product record.
- Self-hosted fonts and no trailer download on passive page load.

## Recommended consolidated page order

1. Category, product-name H1, one concise benefit introduction.
2. Trailer beside the opening on desktop; retain a short purchase-first mobile flow.
3. Price, truthful availability, purchase/access action, format and access facts.
4. “Dla kogo”, including the existing scope boundary about independent falling asleep.
5. Brief “Co obejmuje” overview with the complete topics available by disclosure.
6. A truthful complete chapter outline, or an explicitly identified preview.
7. Real approved testimonials only when present; a final purchase action after details.

Avoid maintaining a manual sales topic list and a chapter outline as competing
claims about completeness. Structured metadata should establish quantity and
duration; the owner's rich text should explain value and suitability.

## Recommended actions

1. **[P1] `$impeccable harden`** — reconcile program completeness and make the
   featured route deterministic; consolidate HTML destinations without changing
   playback or checkout identity.
2. **[P2] `$impeccable clarify`** — expose delivery/access facts by the buy action
   and distinguish any partial outline from the full program.
3. **[P2] `$impeccable distill`** — establish the product-name hierarchy, one
   opening message and the landing's existing progressive disclosure.
4. **[P3] `$impeccable adapt`** — apply the project target size to any retained
   back link and verify the final page at narrow widths and enlarged text.
5. **[P3] `$impeccable polish`** — finish the trailer presentation and verify the
   consolidated layout on mobile and desktop.

You can ask me to run these one at a time, all at once, or in any order you prefer.
Re-run `$impeccable audit` after fixes to reassess the result.
