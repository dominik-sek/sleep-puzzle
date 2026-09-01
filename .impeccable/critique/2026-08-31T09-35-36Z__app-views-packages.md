---
target: app/views/packages
total_score: 16
max_score: 36
na_heuristics: 7
p0_count: 2
p1_count: 2
timestamp: 2026-08-31T09-35-36Z
slug: app-views-packages
---
Method: dual-agent (A: design review · B: detector + static evidence). Both isolated; A never saw B.

TOOLING CAVEAT: the bundled detector's directory walker excludes `.erb` (SCANNABLE_EXTENSIONS in detector/node/file-system.mjs). Verified: walkDir("app/views/packages") and walkDir("app/components") each return 0 files; walkDir("app/views") returns only pwa/service-worker.js. Directory-mode detector runs on this repo scan NO markup and their `[]` means "nothing scanned", not "nothing found". Explicit .erb file paths DO scan, via the regex engine, which self-reports DEGRADED (no HTML parser modules) - an acknowledged undercount. All five target files scanned individually: 0 findings, exit 0.

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 1 | Nothing signals the CTA leads to a login wall; the page never surfaces cost or sellability. |
| 2 | Match System / Real World | 3 | Hero subtitle is genuinely Karola's register; cards lead with the seller's SKU name. |
| 3 | User Control and Freedom | 1 | CTA hits authenticate_user!; after_sign_in_path_for hard-returns dashboard. Package choice discarded. |
| 4 | Consistency and Standards | 2 | Seven amber elements in one viewport. shadow-xs on cards, shadow-sm on CTAs vs Flat Page Rule. Fixed grid vs prescribed auto-fit. |
| 5 | Error Prevention | 1 | No check that the Paddle price is readable; an unsellable package renders a live amber CTA. |
| 6 | Recognition Rather Than Recall | 1 | Comparison page with nothing to compare on - no price, no differentiator, N identical CTA labels. |
| 7 | Flexibility and Efficiency | n/a | Single-visit Persuade surface; one decision, no repeated task. |
| 8 | Aesthetic and Minimalist Design | 3 | Restrained, correctly tokenised - 3 `!` overrides vs home's 19, zero cool greys, zero dark:. |
| 9 | Error Recovery | 2 | Empty state is warm and is a content block, but its copy says "Napisz do mnie" with no link to write. |
| 10 | Help and Documentation | 1 | Answers neither "which one" nor "what does it cost". Scored not n/a: a pricing page with no price is a help failure. |
| **Total** | | **16/36** | **Poor (44%)** |

Lower than home's 21/36 despite better craft: home's failures were defects on a page that worked; these are structural.

## Design Specificity Verdict

The card is authored for this product. The page around it is not.

_card.html.erb is the most on-brief file in the repo - amber circle-check for core benefits, coral astroid for subordinate add-ons, the exact two-tier hierarchy DESIGN.md specifies and nothing else implements. Four `if` guards make "absent rather than empty" real.

The page around it is a canonical SaaS pricing page with the prices deleted. The deletion is the tell: a pattern whose load-bearing elements (price, recommended tier, comparison row) were removed, leaving the frame of an argument with no argument inside it.

Two expensive misses: the 3-up symmetric grid is the grammar of tiers, arguing against the stated belief that every family is a different puzzle; and the page that sells access to a specific person carries her name, face, voice and credentials zero times.

Verified independently: after_sign_in_path_for returns dashboard_index_path unconditionally and stored_location_for appears ZERO times in the repo; PackagesHelper is an empty module while ProductsHelper#product_price_label exists; card edge contrast 1.28:1, card-to-page step 1.12:1; CTA 43.6px tall.

## Overall Impression

Craft is better than home - cleaner tokens, correct headings, a real h1 at the right size. It scores worse because craft isn't the problem. This page is kind and not useful: it refuses to answer the only two questions a parent has, then demands an account before discussing either. The shop already solved this twenty lines away.

## What's Working

1. The only faithful implementation of DESIGN.md's signature marker hierarchy in the codebase.
2. Absent-rather-than-empty is complete AND tested - four guards with a spec asserting an unfilled list takes its heading with it.
3. The only page in the repo that sizes its h1 as the doc prescribes; the home P0 did not recur here.

## Priority Issues

### [P0] The CTA discards the decision it exists to capture
_card.html.erb:65 -> bookings_path(package_id:). BookingsController has authenticate_user! with no exception; ApplicationController#after_sign_in_path_for returns dashboard_index_path unconditionally; stored_location_for appears nowhere.
Fix: `stored_location_for(resource) || dashboard_index_path`, and label the wall.
Command: /impeccable harden app/views/packages

### [P0] A pricing page with no price, and no unavailable state
Nothing under app/views/packages reads paddle_price_id. An archived-price package renders a live amber CTA; failure lands after account creation, slot selection, form submission and a held calendar row. Violates Principle 6.
Fix: PackagesHelper#package_price_label mirroring product_price_label; drop the CTA when nil and put a contact link in its place.
Command: /impeccable harden app/views/packages

### [P1] Nothing distinguishes one package from another
N amber pills with identical words plus the navbar's identical amber pill to the same route. Seven amber elements in one viewport. Four identical link names for a screen-reader user.
Fix: a differentiator line per card, the price, a CTA carrying the package name.
Command: /impeccable clarify app/views/packages

### [P1] Fixed 3-column grid for an owner-managed list
index.html.erb:18 md:grid-cols-2 lg:grid-cols-3. One package (likely launch state) renders third-width hugging left of an empty 1240px row. products/index.html.erb:26 already uses auto-fit minmax(240px,1fr).
Command: /impeccable adapt app/views/packages

### [P2] She never meets the person, and the page never ends
Zero mentions of Karola. No contact link, no FAQ, no mention of the audio catalogue. Single bg-ink section, no band rhythm, terminates on the last card's button.
Command: /impeccable layout app/views/packages

### [P3] Component defaults break the Flat Page Rule repo-wide
Card::Component defaults shadow: :xs; Buttons::Component :primary hardcodes shadow-sm. Invisible on ink, so never caught at a call site.
Command: /impeccable polish app/components

## Persona Red Flags

Casey: four buttons say the same words, the thumb-nearest one discards the choice. CTA 43.6px (clears 24px floor, misses 44px thumb target) and is the smallest type on the card. Card edge 1.28:1.

Riley: 0 packages = dead end whose copy says "write to me" with no link. 1 package = third-width card pinned left, likely launch state. 4/8 = orphan rows. All optional fields empty = amber name above amber pill, nothing between; no floor on how bare a purchasable card may be. Long name = text-t3! in a ~370px column, no break-words, overflow-hidden wrapper; breaks the Two-Language Rule. Unreadable price = nothing notices.

Marta (3:41am): cannot learn cost without creating an account. Karola absent. Cannot ask a question. ~1500px comparison memory task with no price anchor. Never told the choice is reversible - the booking form HAS a package select, so it is.

## Minor Observations

- bordered: false silently discarded, same as home.
- No content_for :title.
- t("packages.duration") bakes its label into the locale value - the one visible sentence the owner cannot reword, against Principle 4; also a sentence in Baloo 2 against the Display-For-Names Rule. Polish pluralisation is correct.
- Eyebrows are bare spans with no programmatic tie to the list they head.
- The two package treatments are drifting: home renders for_whom unguarded (empty <p> possible), duration text-t5 there vs text-t6 here.
- The ladder is inverted site-wide: cheapest step is the least visible element, most expensive is the loudest.
- py-3 layers over the component's py-2 with no `!`; winner decided by stylesheet ordering, not specificity.

## Questions to Consider

1. If the price belongs to Paddle, what does this page do that home's teaser doesn't do better?
2. Three symmetric cards is the grammar of tiers. Which is the lie - the grid, or the belief?
3. One allowed action: "book and pay", or "tell me what's happening and I'll say which one"?
4. What if the largest element on the card were something Karola said?
5. Home was reworked to stop ending on an ask. Why does this page end on three?
