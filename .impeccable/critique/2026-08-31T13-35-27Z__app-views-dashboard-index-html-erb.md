---
target: app/views/dashboard/index.html.erb
total_score: 19
max_score: 40
na_heuristics: 
p0_count: 2
p1_count: 3
timestamp: 2026-08-31T13-35-27Z
slug: app-views-dashboard-index-html-erb
---
Method: dual-agent (A: design review · B: detector + browser evidence). Both isolated; A never saw B. Both browsed the live signed-in dashboard; neither submitted the account form.

Mode: Operate. The sale already happened; every element is a control or a label for one. All ten heuristics scored.

TOOLING: detector exit 2, 7 design-system-font-size findings, zero false positives. B's manual sweep found 13 arbitrary bracket values - the detector only has a font-size rule, so max-w-[], rounded-[] and tracking-[] pass unnoticed. On this surface the tool sees about half the drift.

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 1 | Every player reads 0:00/0:00 until pressed. No duration, though length_minutes is in the DB and unused here. |
| 2 | Match System / Real World | 3 | Booking status copy is good. "Audioproces" is the only metadata under each recording. |
| 3 | User Control and Freedom | 2 | No reorder, no resume, no way to mark anything. |
| 4 | Consistency and Standards | 1 | Uppercase accent h2s break two Named Rules at once. Nine off-ramp text-[Npx]. rounded-[22px] twice. Hand-rolled cards and buttons while both components exist. |
| 5 | Error Prevention | 3 | The streamable? guard is honest engineering. Docked because a paid-for, unplayable product renders with no explanation. |
| 6 | Recognition Rather Than Recall | 2 | Two identical moon rows with identical subtitles. Nothing to recognise a recording by. |
| 7 | Flexibility and Efficiency | 1 | No deep link to a recording, ever. |
| 8 | Aesthetic and Minimalist Design | 2 | Broken by the light-skinned native player and by three headings pixel-identical to the footer's column labels. |
| 9 | Error Recovery | 2 | If the signed URL fails, the play button silently does nothing, forever. |
| 10 | Help and Documentation | 2 | Empty states carry the right link, but nothing explains why there is no download. |
| **Total** | | **19/40** | **Poor (48%)** |

## Design Specificity Verdict

A generic account page wearing the product's colours.

The tell is the most important object on the screen. Positioning is "audio is streamed, never handed over" - which makes this not an account screen with a bonus player but the only place the thing the buyer paid for actually exists. It is a media library, and its player is bare <audio controls> with two utility classes.

Verified: color-scheme is declared NOWHERE in the app, so Chrome paints its light skin. On a 390px phone three white 54px capsules are the brightest objects on an ink #211e1c page. The system's central claim is One Lamp; the brightest thing on screen is a browser default. A confirmed in-browser that one line flips them dark.

Beyond that: no duration, no resume, no last-played, no grouping by kind. The layout spends the primary top-right slot on Sign Out - the one action that removes access - while the navbar already carries sign-out twice. Three sign-out controls; zero authored play affordances.

Verified independently: zero color-scheme declarations; dashboard_index_path carries no anchor; length_label unused on this page (0 occurrences) though the model has it; UA focus blue 2.77:1 on ink vs accent 6.69:1; taupe 12px on surface 4.93:1; the dashboard h1 is the last text-t2 holdout of six entrypoints.

## Overall Impression

The engineering judgment is good - preload="none" so no token is minted until play, upcoming deliberately including pending bookings, empty states that always carry the link that fills them. The design never asked what this page is for. The single biggest issue is one line of CSS.

## Priority Issues

### [P0] The player is a light-skinned browser default on a page built for night use
No color-scheme anywhere. Off-palette cool grey against the Warm Neutral Rule, brightest element on screen for someone defined as operating beside a sleeping child, and the least branded object on the page while three section labels burn the accent.
Fix: color-scheme: dark on :root fixes brightness immediately. Then make play the One Lamp - accent play button, name, length_label as duration - keeping <audio> as a hidden engine so preload="none" and the aria-label survive.

### [P0] "Posłuchaj w koncie" is a promise this page breaks
The shop's owned button links to dashboard_index_path with NO anchor. The button says "Listen in your account"; the page delivers "here is your account, find it yourself." With no visual distinction between recordings a three-purchase library already buries the target below the fold on a phone. Worse: the biggest tappable thing in each row links to product_path - the sales page for something already owned.
Fix: anchor to dom_id(product), add the id and scroll-margin-top to the row, highlight on :target.

### [P1] The settings copy assumes a password Google users do not have
dashboard.settings.body reads "Zmień adres e-mail, hasło i dane konta" unconditionally. NUANCE: the destination handles this correctly - devise/registrations/edit branches on password_set? and relabels to "Ustaw hasło", and the registrations controller skips the current-password check. The architecture honours the constraint; only this one-line summary does not. A Google user clicks "change your password" and lands on "set a password".
Fix: a second CMS field selected by current_user.password_set?.

### [P1] Section headings break two Named Rules and read as footer chrome
text-[15px] font-extrabold uppercase tracking-[0.5px] text-accent on an h2. Uppercase Ceiling: uppercase only at Label size, in Taupe - "there is no uppercase heading anywhere in this system." They render identically to the footer's column labels, so the page's primary structure reads as chrome.

### [P1] Nine off-ramp font sizes; the 12px ones sit below the system floor
15px invents a step between t6 and t5. 12px is below t6 entirely and carries the booking status pill - the one string a buyer must not miss. Measured 4.93:1 taupe on surface, clearing AA by 0.43 for a user defined as having low reading capacity, at night.

### [P2] The empty state is a paragraph, and it is the first thing every new user sees
Every sign-in lands here, so this is the onboarding screen. A new sign-up sees two grey sentences and their own email. The "Umów termin" link measures 19x97px, while the shop card carries a comment about clearing 44px "one-handed in the dark".

## Persona Red Flags

Casey: taps the obvious 958px-wide row target, lands on a sales page for something already owned, reasonably concludes the purchase did not register. Two identical moon rows. Sign Out is the first in-content control.

Sam: product row links have no useful accessible name, and the player is a sibling of the title, so there is no programmatic relationship between the recording and the control that plays it. Duration never announced. Focus ring is Chrome's blue at 2.77:1, below 1.4.11's 3:1, where the system's accent gives 6.69:1 - because the page hand-rolled controls instead of using Buttons::Component. Heading structure is clean; credit due.

3am parent: the screen gets brighter when they need it darkest. Cannot see the length before pressing play. No resume - 18 minutes into a 22-minute story last night means starting from zero tonight.

## Minor Observations

- CORRECTION to Assessment A: it claimed text-t2 is correct for a page title. DESIGN.md:251 assigns Display/t1 to "page H1s only" and t2 to section headings. The dashboard is the last t2 holdout of six entrypoints.
- Product name and booking date are in Quicksand; Display-For-Names covers titles and durations. Both should be Baloo.
- Card::Component and Section::Component's heading_level: slot both exist and are both bypassed here.
- dashboard_spec.rb is strong on behaviour - it covers the non-streamable case BOTH ways, including CDN-unconfigured. So the silent no-player state is deliberate and tested, not an oversight. The question is whether silence is right, not whether anyone noticed.
- bookings.statuses says "confirmed" where orders.statuses says "paid" for the same human meaning.

## Questions to Consider

1. If the shop's button says "Listen in your account", why does the biggest tappable thing in the account link back to the shop?
2. PRODUCT.md says the dashboard "answers the question buyers actually ask." What is the question? If it is "where is my thing and how do I play it", this is a player with settings bolted on, and it is not laid out as one.
3. Why does the One Lamp burn on three section labels while the play button is a browser default?
4. What does this show a buyer whose upload failed - a thing they paid for, no player, no explanation, no way to ask. Is silence the right answer or the worst one?
5. A new user lands here and sees two grey sentences and their own email. If the empty state is the highest-traffic version of this page, why is it the version that got a <p> while the filled state got cards?
