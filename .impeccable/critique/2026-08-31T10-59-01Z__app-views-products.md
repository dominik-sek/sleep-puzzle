---
target: app/views/products
total_score: 19
max_score: 40
na_heuristics: 
p0_count: 2
p1_count: 3
timestamp: 2026-08-31T10-59-01Z
slug: app-views-products
---
Method: dual-agent (A: design review · B: detector + static evidence). Both isolated; A never saw B.

Mode: Operate. The defining moment is a state mutation with four mutually-exclusive control states, a session cart, and four Turbo-streamed regions that must agree. Persuade would excuse heuristics 7 and 10, which is where this surface is weakest. All ten applicable.

TOOLING: detector exit 2, 17 design-system-font-size advisories, ZERO false positives (every flagged line checked against ERB comment spans). B's manual sweep found 21 arbitrary font sizes, not 17 — the regex misses text-[clamp(...)] and decimal px like text-[15.5px]. The tool understates this surface by ~20%. Directory targets still match zero .erb files; explicit paths route to the regex engine, never the DOM engine.

CORRECTION carried from the previous turn: "zero Unicode star glyphs remain in any view" was literally true (I grepped ✦) but framed as the defect class being cleared. Three glyph-as-icon uses survive: ✓ at products/_cart_actions.html.erb:30 (in scope) and ✕ at cart/_line.html.erb:29 (out of scope). circle-check.svg and x.svg both exist.

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 1 | No in-flight state on any control; Buttons::Component has an unused loading: param. On the grid the only confirmation is the button flipping to a destructive verb. |
| 2 | Match System / Real World | 2 | The spec strip advertises "MP3 do pobrania" for a stream-only product. |
| 3 | User Control and Freedom | 3 | Toggle not counter, idempotent add, cart link only when non-empty. Deducted: remove occupies the identical coordinates add just held. |
| 4 | Consistency and Standards | 1 | Nine conventions from the reworked packages/_card absent; five invented radii; 21 off-ramp font sizes; border-taupe-dark as a control boundary. |
| 5 | Error Prevention | 2 | Server-side excellent. Client-side thin: a signed-out returning buyer gets no warning before adding what they own. |
| 6 | Recognition Rather Than Recall | 3 | Deducted: shop.card.details declared and rendered nowhere; the only route into a product is an 18px unstyled name link. |
| 7 | Flexibility and Efficiency | 2 | No whole-card target, no focus styles, no split by kind. |
| 8 | Aesthetic and Minimalist Design | 2 | Largest element on the product page is a 110px emoji; with no type ramp the hierarchy is arbitrary. |
| 9 | Error Recovery | 1 | "Chwilowo niedostępne" is terminal with no route out — packages solved this. Owned-item refusal is a JS-only toast. |
| 10 | Help and Documentation | 1 | No preview, no definition of "audioproces", no delivery explanation, no withdrawal note on a digital EU sale. |
| **Total** | | **19/40** | **Poor (48%)** |

## Design Specificity Verdict

Authored — but by a different, less careful hand than the rest of the site.

The product thinking is the best in the repo: toggle-instead-of-quantity argued from the product, the price guard on BOTH entrypoints, the owned branch routing to the library, streaming the whole cart cluster, and "a GET that mutates gets fired by every link prefetcher going".

The visual layer is a generic e-commerce grid wearing the palette. Against packages/_card the divergence is a fork: Buttons::Component vs hand-rolled rounded-[20px]; aria_label vs none; break-words vs clipping inside overflow-hidden; mt-auto vs flex-1 on an optional paragraph; Baloo name vs Quicksand; a contact route when unpriced vs a dead end. All landed on packages recently and were not carried across.

Packages and about open h1 at text-t1. The shop index opens at text-t2 and show hand-rolls clamp(28px,4.5vw,40px) — t2 re-implemented with the vw coefficient changed for no stated reason. Neither shop entrypoint uses the Display step. PRODUCT.md says the catalogue is the lower rung of a ladder; the design says it is the lesser page.

Verified independently: no download route or attachment disposition exists anywhere; Cart#owned? is `@owner.present? && owned_ids.include?` so it is always false signed out; taupe-dark measures 1.87:1 on surface and 2.09:1 on ink vs a 3:1 requirement; border-input would give 3.30 and 3.69.

## Overall Impression

The surface where the commerce logic is most correct and the craft is least. The hard part — never selling what cannot be honoured — is done properly at two layers. The easy part — using the design system that already exists — was skipped. Biggest opportunity is not on the defect list: you have a signed-URL streaming pipeline, a working <audio> element, and a positioning document saying the differentiator is her voice, and the shop sells that voice with an emoji. A 30-second sample is the highest-leverage missing element, and every part needed to build it already exists.

## What's Working

1. Commerce truthfulness is structural: price guard gates the toggle on index and the entire cluster on show; Cart#total_label returns nil rather than a total omitting a line; published scope excludes anything without a cdn_path and the validation refuses the publish.
2. The toggle is argued from the product, not convention — no quantity stepper for a file with no quantity, idempotent add, both branches real forms.
3. The specs are the best in the repo: price-unavailable, already-owned, all three toggle branches, Turbo stream targets, cart purged on sign-in.

## Priority Issues

### [P0] The spec strip sells a downloadable file that does not exist
show.html.erb renders format_value, default "MP3 do pobrania" / "Downloadable MP3". Verified: no download route, no attachment disposition, delivery is <audio preload="none"> against a 6-hour signed URL, and PRODUCT.md says audio is streamed, never handed over. A false statement of the main characteristic of a digital good, under the price, on an EU distance sale. Worst for the primary user: a parent who buys it for 3am offline discovers at 3am they need signal.
Fix: change the default to "Audio do odsłuchania online" / "Streaming audio" and say playback happens in the account.
Command: /impeccable clarify app/views/products

### [P0] Nothing in the shop is a pill, and control borders fail 1.4.11
Every control is hand-rolled instead of Buttons::Component. Buttons carry rounded-[20px] and the card carries rounded-[20px], so radius signals nothing — Pill-For-Action is inverted, not bent. Controls are bounded with border-taupe-dark: 1.87:1 on surface, 2.09:1 on ink, against 3:1. border-input gives 3.30/3.69. The affected control is the one used to undo a purchase decision.
Command: /impeccable polish app/views/products

### [P1] No focus styles anywhere; every grid button anonymous to a screen reader
Zero focus-visible across all eight files (confirmed independently). Falls back to the browser's cool-blue ring on a warm-dark palette. Every card button reads the identical string — a screen reader tabbing twelve products hears "Dodaj do koszyka" twelve times, the exact failure packages/_card was fixed for.
Command: /impeccable audit app/views/products

### [P1] ~36px add button whose remove state occupies the same pixels
px-4 py-2.5 text-[13px] on the grid; packages was raised to py-4 to clear 44px. The button flips in place to a destructive remove with no confirm and only a JS toast. Casey's likely path: tap add, nothing visibly happens, tap again, second tap removes it — empty cart, user believes the site is broken.
Command: /impeccable harden app/views/products

### [P1] Three card regressions packages already fixed
Long names clip (overflow-hidden, no break-words, 240px columns). CTAs do not align because flex-1 sits on the optional description rather than mt-auto on the price row. Product name is Quicksand here, Baloo on the product page and packages.
Command: /impeccable polish app/views/products

### [P2] Two dead ends and a dead content block
Unpriced product is an unbuyable page with no route out (packages offers contact). Zero-product state is a bare paragraph with no onward route. shop.card.details is declared, editable, rendered nowhere — a field in the panel that changes nothing, inverting Principle 4.

## Persona Red Flags

Casey: the double-tap failure. Only route into a product is an 18px name link with no underline or link colour; Casey taps the 150px emoji panel, which is aria-hidden and inert.

Riley: already-owned-and-signed-in is the best-handled edge here. Already-owned-and-signed-out is broken — Cart#owned? is always false with no owner, so a returning buyer adds what they own and learns only after signing in; nothing invites them to sign in. Unpublishing an in-cart product drops it silently while already_owned gets an explanatory panel. One product stretches to the full 1240px.

3am parent: not told what they are buying (no preview), not told what "audioproces" means, not reassured at the money moment on the cheaper rung, and not shown the ladder — no link to packages on either shop page.

## Minor Observations

- Two h2s on show are 13px uppercase amber eyebrows while a third is text-t3 display cream. Uppercase headings in accent break the Uppercase Ceiling Rule twice.
- text-[11px] labels are 3px below the Label floor — smallest type on the site, on the surface for the most impaired reader.
- Length renders twice on show. Price colour has three answers across the shop.
- The catalogue is a div of divs; as a list it should be ul/li so the item count is announced. The page never states it.
- _cart_toggle puts a form inside a span. Invalid content model.
- The emoji is a deliberate owner-editable field ("the design gives each one a distinct icon, so `icon` is the real source"), so the fix is not an SVG icon set — that removes her control. It is cover art or a sample.

## Questions to Consider

1. You have the pipeline, the player, and a positioning document about her voice. What is the argument for selling audio with an emoji instead of thirty seconds of it?
2. packages/_card was reworked and products/_card was not. Is the shop a second surface, or the same surface with a different noun?
3. Catalogue and consultations are one ladder. Where, on either shop page, is the rung above?
4. The add button flips to remove at the same coordinates with no confirm. How many removes are intentional? No analytics, correctly — so it must be right by construction.
5. shop.card.details has been editable and inert. How many other blocks are fields she can change that change nothing?
