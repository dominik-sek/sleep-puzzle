# `/audioproces` technical audit — 13 October 2026

Follow-up: the two requested P1 findings were addressed in the [hardening pass](/Users/dominiksek/RubymineProjects/sleep-puzzle/.impeccable/harden/2026-10-13__audioproces.md). The report below preserves the original audit observations and score; a full re-audit has not been performed.

Current follow-up: the [polish pass](/Users/dominiksek/RubymineProjects/sleep-puzzle/.impeccable/polish/2026-10-13__audioproces.md) confirms the repaired heading and fixes cart keyboard focus. The completeness guard works, but the local product now declares **1 expected chapter**, matching its single uploaded chapter, while its editable copy still promises **24 recordings**. That content/configuration mismatch remains open; the guard is not proof of offer accuracy. The [optimization pass](/Users/dominiksek/RubymineProjects/sleep-puzzle/.impeccable/optimize/2026-10-13__audioproces.md) deferred editor/calendar code.

## Implementation integrity verdict

**Fail for release readiness in the inspected local state; the visual system is coherent.** Sleep Puzzle's warm dark tokens, self-hosted typography, editable owner content, and shared purchase controls are consistent. However, the offer advertises 24 recordings while its local product contains only one ready chapter, and malformed markup destroys the program heading. These are content and implementation defects, not a reason to replace the design.

The bundled detector returned four advisory findings. None is an actionable defect on this route: the 110px value sizes an aria-hidden decorative emoji; `#fff` belongs to an unused scaffold form-control rule; the two black alpha colors belong to consultation/package-dialog backdrops that are absent here and explicitly documented in DESIGN.md. The detector does not catch the broken ERB-generated markup, media recovery, or commerce-state gates found below.

## Audit health score

| Dimension | Score | Key finding |
|---|---:|---|
| Accessibility | 2/4 | Program heading is swallowed into an attribute; cart mutation loses keyboard focus. |
| Performance | 2/4 | Main shared JavaScript is 545.58 kB minified, including unused editor/calendar code. |
| Responsive design | 4/4 | No horizontal overflow at 320, 390, 768, or 1440px; inspected public controls meet 44px targets. |
| Theming | 4/4 | Core colors and type roles match the documented intentionally dark system. |
| Implementation integrity | 2/4 | Advertised contents disagree with local deliverable; access and trailer failure states need work. |
| **Total** | **14/20** | **Good — address weak dimensions and the two major findings before release.** |

These are bounded audit scores, not accessibility certification or measured Core Web Vitals. Responsive scoring covers the inspected content and viewport widths; 200% text-only resizing and every assistive technology were not tested.

## Executive summary

**6 confirmed findings: P0 0 · P1 2 · P2 4 · P3 0.** One additional media-accessibility verification remains open and is not counted as a confirmed violation.

Priorities:

1. Restore the chapter section's HTML and semantic heading.
2. Reconcile the 24-recording offer with the actual deliverable before selling it in this state.
3. Preserve keyboard focus through cart updates and keep existing-purchase access available during price-service outages.
4. Give trailer failure a recovery path and reduce the shared JavaScript paid for by passive readers.

The recording-count mismatch and playback failure were observed locally. Neither establishes the state of production.

## Detailed findings by severity

### [P1] 1. Unclosed section attribute consumes the chapter heading

- **Location:** [chapter outline, line 3](/Users/dominiksek/RubymineProjects/sleep-puzzle/app/views/products/_chapter_outline.html.erb:3).
- **Category:** Accessibility / Implementation integrity.
- **Evidence:** The opening `<section>` leaves `aria-label` unclosed and omits the closing `>`. The browser parses the next `<h2 class=` into the accessible region name. Both the DOM snapshot and accessibility tree expose `Program audioprocesu <h2 class=`. The rendered section contains no H2; its visible title falls back to ordinary body styling.
- **Impact:** Screen-reader heading navigation skips the program, the region name contains code, and sighted readers lose the intended section hierarchy.
- **Standard:** The heading relationship is no longer programmatically represented, contrary to [WCAG 1.3.1, Info and Relationships](https://www.w3.org/WAI/WCAG21/Understanding/info-and-relationships.html).
- **Recommendation:** Close the attribute and opening tag. Prefer an H2 with a stable ID referenced by `aria-labelledby`, avoiding a duplicated heading string. Add a parsed-response assertion for the real heading and region name; checking only response text would miss this defect.
- **Suggested command:** `$impeccable harden /audioproces`.

### [P1] 2. The advertised program disagrees with available chapters

- **Location:** [includes content output, line 47](/Users/dominiksek/RubymineProjects/sleep-puzzle/app/views/audio_processes/show.html.erb:47), [chapter filtering, line 1](/Users/dominiksek/RubymineProjects/sleep-puzzle/app/views/products/_chapter_outline.html.erb:1), and [publication validation, line 232](/Users/dominiksek/RubymineProjects/sleep-puzzle/app/models/product.rb:232).
- **Category:** Implementation integrity.
- **Evidence:** The local page advertises “24 krótkie, ale treściwe nagrania” and offers an add-to-cart action at 497,00 PLN. Its displayed program contains only `1. Wstęp — 2:52`. A read-only query of that selected product confirms exactly one chapter in total, ready, lasting 172 seconds. This is not just 23 hidden pending uploads. Publication validation requires only one ready chapter, and the published scope likewise checks for the existence of one recording.
- **Impact:** A visitor cannot reconcile the paid offer with the program actually available. If this data is released unchanged, the delivery would not match the presented offer.
- **Standard:** PRODUCT.md's truthful-commerce requirement. No claim about the production database or legal compliance is made.
- **Recommendation:** Verify and complete the real program before offering this local state for sale. Establish an explicit owner-controlled completeness check for multi-chapter products, rather than treating one ready chapter as proof that an advertised program is complete. Reconcile editable copy with the verified contents; do not invent or silently rewrite the offer.
- **Suggested command:** `$impeccable harden /audioproces`.

### [P2] 3. Cart updates drop keyboard focus to the page body

- **Location:** [cart stream replacement, line 27](/Users/dominiksek/RubymineProjects/sleep-puzzle/app/views/cart_items/create.turbo_stream.erb:27); the destroy stream uses the same replacement; [cart-actions wrapper, line 14](/Users/dominiksek/RubymineProjects/sleep-puzzle/app/views/products/_cart_actions.html.erb:14).
- **Category:** Accessibility.
- **Evidence:** Activating Add to cart with Enter successfully changes the UI to Remove from cart, Go to cart, and the confirmation note. After the response completes, `document.activeElement` is BODY. The stream replaces the whole cluster containing the submitting button, with no focus restoration. The temporary disabled submit state also loses focus in this browser. The session-cart test was undone and the original Add action verified after reload.
- **Impact:** Keyboard users lose their position just as the next action appears. The polite confirmation conveys status but does not preserve the user's navigation position.
- **Standard:** Keyboard continuity and focus-order concern; this bounded observation alone is not asserted as a universal WCAG failure.
- **Recommendation:** Keep a stable control/cluster where practical, or explicitly restore focus to the corresponding replacement control when focus originated there. Preserve the submit-in-progress feedback and live announcement; avoid moving focus for mouse/touch users or after they have moved elsewhere.
- **Suggested command:** `$impeccable harden /audioproces`.

### [P2] 4. Price failure also hides access for existing buyers

- **Location:** [landing price gate, line 13](/Users/dominiksek/RubymineProjects/sleep-puzzle/app/views/audio_processes/show.html.erb:13), [shared actions price gate, line 15](/Users/dominiksek/RubymineProjects/sleep-puzzle/app/views/products/_cart_actions.html.erb:15), and [ownership branches, line 24](/Users/dominiksek/RubymineProjects/sleep-puzzle/app/views/products/_cart_button.html.erb:24).
- **Category:** Implementation integrity.
- **Evidence:** Both the landing page and shared action wrapper require `product_price_label` before rendering any action. The owned-product and pending-payment links live inside that gate. When the price lookup returns nil, those branches cannot render, even though they navigate to an existing purchase rather than start a new sale. This is a deterministic source-level finding; no price outage or signed-in account was forced during the audit.
- **Impact:** A buyer returning during a Paddle price-catalogue outage loses the direct route to their recording or payment status. The account navigation remains a workaround.
- **Standard:** PRODUCT.md's owned/pending purchase behavior and graceful recovery requirements.
- **Recommendation:** Resolve ownership and pending-payment states before price availability. Gate only new-sale actions on a current price. Avoid redundant outer price gates that bypass the shared component's state decisions.
- **Suggested command:** `$impeccable harden /audioproces`.

### [P2] 5. Trailer failure has no page-level recovery

- **Location:** [trailer partial, line 4](/Users/dominiksek/RubymineProjects/sleep-puzzle/app/views/products/_trailer.html.erb:4), [trailer availability predicate, line 182](/Users/dominiksek/RubymineProjects/sleep-puzzle/app/models/product.rb:182), and [public trailer endpoint, line 45](/Users/dominiksek/RubymineProjects/sleep-puzzle/app/controllers/products_controller.rb:45).
- **Category:** Implementation integrity.
- **Evidence:** A public playback attempt in the local in-app browser produced the native accessible message `Nie można odtworzyć multimediów.` The page has no surrounding failure explanation, retry action, or alternative introduction. `trailerable?` establishes only a configured signer and stored path. The view has no error handling or fallback child content. The cause of this playback failure was not established; it could involve the local media URL, delivery, or browser support.
- **Impact:** Visitors cannot hear the introduction or tell how to recover. The unavailable preview weakens their ability to assess the owner's voice before buying, although purchase remains possible.
- **Standard:** Recoverable media-state expectation, not a confirmed WCAG violation.
- **Recommendation:** Investigate the failed public playback on the intended browser/device classes. Add a localized media-error message and explicit retry; provide equivalent introductory text as an alternative where available. Keep playback opt-in and preserve `preload="none"`.
- **Suggested command:** `$impeccable harden /audioproces`.

### [P2] 6. Passive readers download an oversized shared application bundle

- **Location:** [eager controller registration, line 4](/Users/dominiksek/RubymineProjects/sleep-puzzle/app/frontend/controllers/index.js:4) and [global editor/calendar imports, line 8](/Users/dominiksek/RubymineProjects/sleep-puzzle/app/frontend/entrypoints/application.js:8).
- **Category:** Performance.
- **Evidence:** A successful current-source production build emits the main application JavaScript at **545.58 kB minified / 152.45 kB gzip** and reports its >500 kB chunk warning. Every Stimulus controller is imported eagerly. Cally, Trix, Action Text, Active Storage, and their supporting code enter the shared entrypoint even though the inspected route has no calendar, editor, or upload form. PhotoSwipe's viewer is already split into a separate dynamic chunk and should not be described as an eagerly loaded viewer.
- **Impact:** Mobile readers pay download, parsing, and evaluation costs for unrelated tasks before they interact with this simple purchase page. No slow-device timings or field Core Web Vitals were measured, so this is a demonstrated bundle cost, not a measured interaction-latency failure.
- **Standard:** Performance budget / route-specific loading practice; no WCAG criterion.
- **Recommendation:** Separate staff editor/upload code from the public entrypoint and load calendar functionality only where needed. Retain Turbo navigation support when registering deferred controllers. Use the existing dynamic viewer import as a local model, then compare built transfer size and slow-device behavior.
- **Suggested command:** `$impeccable optimize /audioproces`.

## Additional media-accessibility verification

The trailer has no `<track>` element, and the DOM exposes zero selectable text tracks. No corresponding transcript or equivalent introduction is linked from the player; the product model and upload flow contain no caption field. This is a verified implementation gap, but **a caption-conformance failure is not confirmed**: playback failed before the actual media could be inspected for burned-in captions or its relationship to the surrounding text.

Before release, inspect the real trailer. Prerecorded synchronized media with meaningful audio generally requires captions under [WCAG 1.2.2, Captions (Prerecorded)](https://www.w3.org/WAI/WCAG21/Understanding/captions-prerecorded.html); open captions or a correctly labeled equivalent-text alternative may change the assessment. If needed, add owner-managed, self-hosted WebVTT captions and a readable transcript. If the asset is audio-only despite its video container, evaluate the appropriate audio-only alternative requirement instead. Do not mark this resolved merely because the player has an `aria-label`.

## Patterns and systemic issues

- **Technical readiness is weaker than offer completeness.** One nonempty chapter path permits publication of a product whose editable offer can promise substantially more.
- **Purchase availability and access are coupled.** Reused price gates suppress state-specific navigation that should survive price-service failure.
- **Partial replacement lacks a focus contract.** The cluster updates correctly visually but has no explicit keyboard continuation behavior.
- **One eager entrypoint serves unrelated audiences.** Staff editing and consultation tooling are included in a passive product-reading route.

## Positive findings

- The existing color/type system is appropriate and consistently applied. No replacement theme is needed. The deliberate dark-only policy is documented; absence of a light-mode toggle is not a defect.
- Sampled token combinations pass normal-text AA contrast: cream on ink **14.61:1**, tan on ink-soft **9.43:1**, taupe on surface **4.93:1**, and ink on amber **6.69:1**. These calculations cover the inspected tokens, not every possible CMS image/content color.
- H1, a main landmark, page language, and a focusable skip link are present. Keyboard menu activation moves focus to its first link, uses a visible 2px amber outline, and Escape returns focus to the trigger.
- No horizontal overflow was measured at **320, 390, 768, or 1440px**. Visible custom navigation/cart controls and footer links meet the **44px** target floor; the primary action is approximately **54px** high. Native media-control internals were not included in this measurement.
- The hero's rich-text lead correctly resolves to the lead typography modifier, avoiding the inheritance defect seen elsewhere in older audits.
- Native video controls, `playsinline`, reserved aspect ratio, no autoplay, and `preload="none"` are sensible defaults. Navbar reduced-motion styles preserve immediate state feedback rather than globally killing all motion.
- New purchases are suppressed when no Paddle price is available. Owned/pending branches exist and use anchored account links when price is available.
- Cart actions use real forms, submission feedback, and a live status note. Empty testimonials disappear rather than generating invented social proof.
- Fonts are self-hosted with swap and Polish character subsets. No third-party script, iframe, or image URL was present in the passive page DOM inspected before playback.

## Recommended actions

1. **[P1] `$impeccable harden /audioproces`** — repair the parsed chapter markup and establish truthful program completeness before purchase is offered.
2. **[P2] `$impeccable harden /audioproces`** — preserve cart keyboard focus, decouple owned/pending access from live pricing, and add trailer recovery; resolve the media-accessibility verification against the real asset.
3. **[P2] `$impeccable optimize /audioproces`** — split unused editor/upload/calendar code from passive public reading.
4. **Final step: `$impeccable polish /audioproces`** — confirm the repaired heading hierarchy and interaction details without replacing the established visual system.

You can ask me to run these one at a time, all at once, or in any order you prefer. Re-run `$impeccable audit /audioproces` after fixes to see your score improve.

## Scope and evidence

- Inspected `http://localhost:3000/audioproces`, its shared components, current PRODUCT.md and DESIGN.md, and supporting commerce/media code. The context launcher interpreted the absolute route as a filesystem path, so project context was read directly; its missing-file output does not describe this repository.
- Used desktop and phone screenshots, DOM/accessibility snapshots, keyboard interaction, computed sizes, token contrast calculations, a read-only query limited to the selected product's chapter titles/readiness/durations, the bundled detector, and a successful current-source Vite production build.
- No application source or product data was changed. The temporary session-cart addition was removed and the original Add state verified. Temporary viewport overrides were reset.
- English, signed-in ownership/pending states, empty/unpriced states, published testimonials, screen-reader announcements across products, 200% text-only scaling, and production delivery were not exercised live. Source-derived findings are labeled as such. No payment was attempted.
- [Phone screenshot with the original cart state](/Users/dominiksek/RubymineProjects/sleep-puzzle/.impeccable/audit/evidence/2026-10-13__audioproces-mobile.jpg).

![Phone layout at 390px](/Users/dominiksek/RubymineProjects/sleep-puzzle/.impeccable/audit/evidence/2026-10-13__audioproces-mobile.jpg)
