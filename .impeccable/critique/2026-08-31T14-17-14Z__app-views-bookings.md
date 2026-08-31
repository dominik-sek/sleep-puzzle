---
target: app/views/bookings
total_score: 16
max_score: 40
na_heuristics: 
p0_count: 3
p1_count: 2
timestamp: 2026-08-31T14-17-14Z
slug: app-views-bookings
---
Method: dual-agent (A: design review · B: detector + browser evidence). Both isolated; A never saw B. Both browsed the live signed-in page; neither submitted the form or opened the Paddle overlay.

Mode: Operate. A multi-step money task: pick a slot -> fill a form -> pay. All ten heuristics scored.

TOOLING: detector exit 0, zero findings — and the match is COINCIDENTAL. These seven files genuinely contain zero arbitrary bracket values, but the detector reached [] by scanning nothing (.erb excluded from the walker; explicit paths route to the regex engine, which has no generic bracket-value rule). Both facts agree; only one is evidence.

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 2 | Picking a day announces nothing; on a phone it changes nothing visible. |
| 2 | Match System / Real World | 2 | No timezone, no duration, no price. Available days are filled tiles, unavailable ones transparent — inverted from every calendar people know. |
| 3 | User Control and Freedom | 2 | Abandoning checkout wipes day, hour and package. |
| 4 | Consistency and Standards | 1 | The site's most important CTA is not a pill. Four ambers in one viewport. h1 still t2. |
| 5 | Error Prevention | 1 | The booking row AND the Google Calendar hold are written before anyone checks whether Paddle can price the package. |
| 6 | Recognition Rather Than Recall | 1 | At the instant of payment the form restates nothing — not date, time, duration or price. |
| 7 | Flexibility and Efficiency | 2 | Package preselect from the packages card is good. The calendar opens on the current month, not the first available one. |
| 8 | Aesthetic and Minimalist Design | 2 | Two top-aligned cards leave ~400px of void at desktop. |
| 9 | Error Recovery | 2 | abandon_notice reasons better than most production code, then delivers the verdict as an auto-dismissing toast. |
| 10 | Help and Documentation | 1 | Nothing explains what a consultation is, how long, or what happens next. |
| **Total** | | **16/40** | **Poor (40%)** |

Lowest of the seven surfaces reviewed this session, on the highest-stakes page.

## Design Specificity Verdict

Authored at the edges, generic at the centre — and the centre is where the money is.

Real care in the engineering: the unavailable-calendar degradation renders every slot taken rather than free, with a comment explaining that a wrong guess sells a time she is already sitting in someone else's consultation for. The abandon path distinguishes paid from declined from released via an independent payment check, because checkout.closed also fires after success.

But between "Twoje dane" and "Zapłać i potwierdź rezerwację" — the entire commitment — the page says nothing about what is being bought. SLOT_DURATION = 1.5.hours exists and is never shown. Package#duration exists and is never rendered. The price is never rendered at all.

Verified independently: load_package_options emits data-price_id onto every option and NOTHING reads it, while PaddlePriceCatalogService and package_price_label already work on /pakiety; create saves the booking then calls BookingCalendarService then checkout_for; the package label resolves to booking_package while the select emits booking_package_id; bookings has exactly 2 editable content fields; POST /bookings and abandon have zero spec coverage.

## Overall Impression

The seams show where the calendar work and the commerce work were built separately and never joined. The clearest proof is the unconsumed data-price_id: the two halves exist and have never met.

## Priority Issues

### [P0] The buyer presses "Pay" without ever seeing a price, a duration, or a summary
No figure, no 1,5h, no restatement of the chosen slot anywhere in the form. PackagesHelper already says it: "a package we cannot price is a package we cannot sell." /pakiety enforces that; /bookings is the same catalogue with the enforcement removed, at the point where money moves. The fix is smaller than it looks — data-price_id is already in the DOM and the helper already exists.

### [P0] A package Paddle cannot price is bookable — the row and the calendar hold are written first
Verified ordering: @booking.save -> BookingCalendarService.create (holds the Google slot) -> then checkout_for. If Paddle fails, the buyer gets an alert while a pending booking exists, the slot is gone from public availability, and the dashboard reads "Oczekuje na płatność" for an hour until the cleanup job.
Fix: prepare the checkout before saving; fail before writing anything.

### [P0] On a phone, choosing a day produces no visible and no announced change
Measured live at ~560px: calendar bottom 941px against a 701px viewport. The hours card is entirely below the fold, and the only aria-live on the page is the payment overlay.

### [P1] The calendar opens on the current month, so at month-end the business looks fully booked
Verified live on 31 August: one selectable day among forty ghosts; one arrow press revealed a September with availability on almost every weekday. The //todo at cally_controller.js:36 governs this, and @available_dates is already serialised onto the element. There is also no state at all for "reachable calendar, genuinely no free slots".

### [P1] The package select has no accessible name
Forms::Component derives its id from name:, so "booking[package]" -> booking_package, while f.select :package_id emits booking_package_id. The label for points at nothing. The one field that determines what the buyer is charged for is unlabelled.

### [P2] The most important button on the site is not a pill, and is the smallest target in the funnel
38px, rounded-lg, while every other form submit on the site passes pill: true. Pill-For-Action: "round means do, 16px means read."

## Persona Red Flags

Casey: taps a day, nothing appears to happen. Lands on a page that looks fully booked at month-end. Day cells ~40px on a phone. A mis-tap closing the overlay wipes day, hour and package.

Sam: the calendar widget itself is GOOD — verified roving tabindex, arrow keys, cross-month paging, per-cell aria-label, proper th scope="col". Adopting a web component usually costs the keyboard story and here it did not. But neither custom element carries a role or aria-label, so the widget has no accessible name; selecting a day announces nothing; and a fully-booked month contains zero tabbable cells with no text saying so.

3am parent: will press "Zapłać i potwierdź rezerwację" without having seen a number. Never told the consultation is 90 minutes. The time is ambiguous — "08:15" with no timezone anywhere, on an /en route that ships fully translated. If the webhook is slow, an indefinite spinner after a card charge, with no timeout and no "check your email" fallback.

## Minor Observations

- index.html.erb:4 is text-t2. CORRECTION: last turn I said "all six public entrypoints now agree" — bookings is a seventh and was not in that grep. It is now the only t2 holdout.
- _form.html.erb:32 — "Wybierz ponownie termin w kalendarzu." is a RAW LITERAL: not an i18n key, not a content block. English visitors see Polish, Karola cannot reword it, and at text-xs it is below the floor Forms::Component defends — the view overrode the component.
- No ::part(today) rule exists, so today's cell is visually identical to any available day.
- _calendar.html.erb:11 uses raw amber-* — a second amber beside #e2933e.
- bookings declares exactly two editable fields (hero title and subtitle). The confirmation, the failure copy, the pay button and the abandon notices are hardcoded.
- The money path has ZERO test coverage. The spec has 8 examples, all GET /bookings. create, abandon and the Paddle-unpriced branch are untested — in a codebase whose other specs are genuinely strong. That is how the ordering issue survived.

## Questions to Consider

1. If Paddle owns every figure, why does the surface that takes the money show none of them — when the price id is already in the DOM?
2. Why does the booking exist before the checkout does?
3. The abandon path reasons about paid vs declined more carefully than most production systems — and then says it in a toast that disappears.
4. Whose 08:15 is it? No timezone anywhere, on a fully-translated English route.
5. The available day is a filled tile and the unavailable one transparent. Was that read as "available days glow", or is it asking an exhausted parent to invert a lifetime of convention at the moment they are least able to?
