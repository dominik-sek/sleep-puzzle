# Sleep Puzzle — audit after hardening and optimization

27 October 2026. This follow-up expands the original audit to populated commerce, customer/admin accounts, keyboard operation, enlarged text and dynamic announcements. No application code was changed during this audit.

## Implementation integrity verdict

**Pass.** The application retains a coherent Sleep Puzzle design and honest ownership, pending-payment and unavailable states. The original seven findings have been addressed in their stated scope. The wider runtime coverage found **four remaining issues: 2 P1 and 2 P2; no P0 or P3**.

The bundled detector again reported **0 primary findings and 10 existing advisories**. These advisories concern internal CMS highlights, tooltip type size and backdrop/color literals; they are not four additional runtime defects. ERB is not configured as a detector extension and was reviewed manually.

## Audit health score

| Dimension | Score | Evidence |
| --- | --- | --- |
| Accessibility | 2/4 | Corrected form relationships and modal focus pass; payment completion lacks an announcement, and mobile enlargement loses content. |
| Performance | 3/4 | Production-load comparison confirms a 47.3% reduction in home/shop gzip estimates; no new field Web Vitals measurement. |
| Responsive design | 2/4 | Populated normal-size mobile views fit; several 200% text states overflow or clip important content. |
| Theming | 3/4 | Corrected labels/hints use readable warm tokens; existing detector advisories remain. |
| Implementation integrity | 4/4 | Shared components, privacy boundaries, live-price safeguards and product-specific states remain coherent. |
| **Total** | **14/20 — Good, provisional** | **The same overall score now covers substantially more states.** |

This is not a WCAG conformance certificate. The score should not be read as a regression caused by the fixes: the follow-up exercises conditions the initial empty-catalogue inspection could not cover.

## Method and scope

All data was synthetic, transactional test data. External price/calendar reads were stubbed. No real customer account, payment, booking or production record was changed.

Rendered normal and enlarged-text samples covered:

- Populated shop, story and audioprocess detail, and packages.
- A populated cart with a long Polish recording name, price and removal action.
- Customer dashboard with owned audio, pending audio, and pending/confirmed consultations.
- Account settings; additional request coverage includes the passwordless Google-account variant.
- Pending and paid order pages, pending and confirmed booking pages, and a preselected available booking form.
- Admin dashboard, product/package/article creation, consultation calendar and CMS.

The main matrix used a 390px browser window at the normal root font size and at **200% root font size**. Cart, dashboard, order, booking summary and booking form also received a normal 320px sample and a 1280px desktop sample with doubled root text. Those latter samples did not have horizontal document overflow. This is an enlarged-root-text stress test, not a claim that native browser zoom, OS text scaling or every pixel-sized label was tested. A desktop browser at 200% page zoom is a separate configuration.

The focused regression run passed **48/48 examples** across admin keyboard focus, modal Escape/return behavior, public add/remove focus, chapter controls, account variants, availability/ownership rules and form relationships. Separate audit probes exercised the populated matrix and live-region transitions successfully. The previously reported intermittent calendar click in full-suite runs was not diagnosed or declared resolved by this audit.

For announcement checks, Chrome's accessibility tree and live-region properties were inspected after real registration validation, a real cart addition and a rejected booking submission. Payment completion was simulated by sending the application's rendered paid/confirmed partial through Turbo replacement, matching the DOM update used by the webhook flow. **No NVDA, JAWS or VoiceOver speech session was performed**, and a real Paddle overlay/webhook or audible playback was not tested.

## Original finding recheck

| Original finding | Follow-up result |
| --- | --- |
| Faint password/admin guidance | Corrected. Taupe `#9b948a` on Surface `#2b2724` is approximately **4.93:1**, versus 1.87:1 before. |
| Unnamed admin fields | Sampled product/package/article and CMS controls have labels or complete ARIA names, including language. |
| Missing admin language | `lang="pl"` is rendered and the locale controller updates it on Turbo entry from English. |
| Mobile sidebar focus/motion | Native dialog containment, Tab cycling, Escape, return focus, breakpoint close and reduced-motion handling pass. |
| Admin navigation/language targets | Navigation controls and language tabs now have 44px minimum targets. Other controls were outside that adapt request; see finding 4. |
| Globally eager controller bundle | Split verified. Public reading pages no longer request admin, carousel, tooltip or upload support unless their markup needs it. |
| Form instructions/error relationships | Auth, booking and testimonial relationships pass focused coverage; registration and booking errors expose live regions in Chrome's tree. |

## P1 findings

### 1. Payment completion removes the live announcement

- **Category:** Accessibility.
- **Locations:** `app/views/orders/_status.html.erb:13`, `app/views/bookings/_status.html.erb:1`; the paid/confirmed branches have no live wrapper. `app/views/orders/show.html.erb` and `app/views/bookings/show.html.erb` do not provide a persistent live parent around the replaced region.
- **Verified behavior:** Before each replacement, Chrome reports a polite, atomic `status` node for the waiting message. After replacement with the paid/confirmed partial, it reports **no live region**, and keyboard focus remains on `BODY`. The completion heading is visible but has no announcement or focus cue.
- **Impact:** A screen-reader user waiting for confirmation can miss the transition that determines whether a purchase or consultation succeeded.
- **Standard:** WCAG 4.1.3 Status Messages is the relevant requirement. Actual speech behavior still needs assistive-technology confirmation; the missing programmatic status semantics are verified.
- **Recommendation:** Keep a persistent, concise `role="status"`/polite live region outside the replaced payment panel, and update its text on every outcome, including failure/cancellation. Keep the receipt and other long content out of the announcement. Preserve focus unless the user explicitly requested navigation.
- **Suggested command:** `$impeccable harden`.

### 2. Enlarged mobile text loses purchase and booking information

- **Category:** Accessibility / Responsive.
- **Locations:** `app/views/cart/_line.html.erb:14` and `:18`; `app/views/orders/_status.html.erb:13` and `:63`; `app/views/bookings/_status.html.erb:38` onward; clipping is compounded by the shared Card's `overflow-hidden` in `app/components/card/component.rb:92`.
- **Verified behavior at 390px, 200% root text:** The cart row's recording title collapses out of view while price/remove remain. At normal text it is already truncated into a 105px slot for the representative long title. The order confirmation/waiting heading extends offscreen; document width grows to roughly **444–447px**. In the confirmed booking card, payment/status values extend beyond the right edge and are clipped, even though document overflow checks alone report no extra width.
- **Impact:** A magnifying user cannot reliably identify what is being purchased or read the full booking/payment outcome. A simple document-width check misses the clipped booking details.
- **Standard:** Loss of content under enlarged text warrants correction against WCAG 1.4.4 Resize Text. The precise root-font test method is described above; this is not a substitute for native zoom verification.
- **Recommendation:** Stack cart identity separately from price/remove on constrained widths; wrap full product names. Let order headings and receipt metadata wrap with responsive insets. Stack or responsively grid booking term/value pairs instead of forcing them into one row. Retain full status text rather than truncating it.
- **Suggested command:** `$impeccable adapt`.
- **Evidence:** [Cart title disappears](images/audit-postfix-cart-200.png), [order heading exceeds the viewport](images/audit-postfix-order_pending-200.png), [booking status is clipped](images/audit-postfix-booking_confirmed-200.png).

## P2 findings

### 3. Dashboard, calendar and admin controls still overflow with enlarged text

- **Category:** Responsive.
- **Locations:** `app/views/dashboard/index.html.erb:158`, `:172` and `:191`; `app/views/admin/products/_form.html.erb:127`; `app/views/admin/articles/_form.html.erb:149`; calendar sizing around `app/frontend/entrypoints/application.css:473` and `:548`.
- **Verified behavior at 390px, 200% root text:** The customer dashboard grows to approximately **518px** because of its nonshrinking pending-consultation badge and the account-copy/email block. The booking form grows to approximately **499px**; the calendar includes long enlarged weekday content and minimum-sized day columns. Admin product creation has an inner main region around **485px** wide, and the unwrapped save/cancel row pushes “Anuluj” past the right edge. Article creation behaves similarly, with an inner width around **429px**.
- **Impact:** These screens require horizontal navigation or conceal adjacent controls in the visible viewport, increasing reading and editing effort on a phone.
- **Standard:** Project mobile/enlarged-text requirements; inspect native zoom and reflow after correction. This is not a finding against intentionally horizontally scrollable data tables.
- **Recommendation:** Allow pending badges and email addresses to wrap, add `min-width: 0` where appropriate, and wrap/stack save/cancel controls. Review calendar heading/weekday/column geometry under enlarged text without reducing required hit targets or dropping days.
- **Suggested command:** `$impeccable adapt`.
- **Evidence:** [Admin save/cancel row](images/audit-postfix-admin_products-200.png).

### 4. Small targets remain outside the navigation/language-tab fixes

- **Category:** Responsive / Accessibility.
- **Locations:** `app/views/cart/_line.html.erb:26`; the Trix toolbar brought in by `app/frontend/entrypoints/application.js` and `app/frontend/lib/rich_text_editor.js`; `app/views/bookings/_status.html.erb` confirmed-state return action.
- **Verified behavior at normal text:** The cart remove button measures approximately **33×28px**. Trix toolbar controls in the product/article editor measure approximately **20–23×24px**. The confirmed-booking return action is about **38px** tall. The reworked sidebar and language tabs meet 44px and are not included in this finding.
- **Impact:** These frequent controls are less forgiving for touch users than the surrounding interface, particularly during one-handed use or precise text editing.
- **Standard:** PRODUCT.md / DESIGN.md's 44px target commitment. This is **not** described as a WCAG 2.1 AA failure: its 44px target-size criterion is AAA.
- **Recommendation:** Increase hit areas independently of icon artwork. Allow editor toolbar groups to wrap into readable rows and retest selection/link-editing popovers on a phone.
- **Suggested command:** `$impeccable adapt`.

## Announcement and keyboard findings that passed

- Registration validation creates an AX `alert` with assertive, atomic live semantics; invalid fields reference their messages and password guidance.
- A rejected booking submission exposes the booking-frame live feedback and alert; the invalid input relationship survives the frame replacement.
- Cart addition creates polite announcement semantics alongside the replacement action. The keyboard-focus tests preserve focus after keyboard activation without pulling it back after the user moves away.
- Package details contain focus and return it after Escape; mobile admin navigation contains forward Tab cycling, restores focus and honors reduced motion.
- The populated dashboard distinguishes owned content from pending purchases, and pending items are not presented as playable. Purchase availability/ownership regression coverage passes.

These are verified DOM/AX and keyboard observations; they do not guarantee the exact spoken phrasing or timing of every screen reader.

## Patterns, positives and exclusions

The new failures cluster around compact commerce rows and **replacement boundaries**. Stable form contracts now work; asynchronous financial outcomes need the same persistent announcement contract. Shared buttons/forms do not automatically protect custom receipt rows and third-party editor toolbar geometry at larger text sizes.

Preserve the successful changes: readable muted tokens, labelled multilingual editors, explicit admin language, native dialog focus behavior, wrapped public product headings, conditional integrations, and measured controller splitting. Populated customer screens fit at normal 320px/390px, and sampled 1280px desktop enlarged-text states fit. Account settings, product detail and package overviews were resilient in the main enlarged-text sample.

The admin dashboard's normal-size horizontally scrollable data table is an intentional exception, not a whole-page overflow defect. Screen-reader-only text, closed disclosure content and decorative empty image descriptions were excluded from clipping/alt findings. The synthetic confirmed booking lacked a paid timestamp; its “unconfirmed payment” wording reflects fixture data and was not reported as a product bug. Partial English content remains allowed by the brief.

Raw measurements and AX properties: `docs/ui-audit-postfix-2026-10-27.json`. All screenshots use synthetic test data.

## Recommended action order

1. **P1 — `$impeccable harden`:** Add persistent concise announcements for all payment outcomes.
2. **P1 — `$impeccable adapt`:** Preserve cart identity, receipt headings and booking values under enlarged text.
3. **P2 — `$impeccable adapt`:** Wrap dashboard/admin rows and fix calendar enlargement; enlarge remaining commerce/editor targets.
4. **Verification — `$impeccable audit`:** Repeat the same populated cases, add native browser zoom and an NVDA/VoiceOver speech pass, and retain the existing keyboard/form regressions.
5. **Finish — `$impeccable polish`:** A bounded visual consistency pass after those functional corrections.

These commands can be run individually, together, or in a chosen order. Re-run `$impeccable audit` after fixes to update the provisional score.
