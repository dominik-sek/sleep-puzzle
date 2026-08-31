---
target: app/views/contacts
total_score: 15
max_score: 40
na_heuristics: 
p0_count: 2
p1_count: 2
timestamp: 2026-08-31T12-11-11Z
slug: app-views-contacts
---
Method: dual-agent (A: design review · B: detector + browser evidence). Both isolated; A never saw B. Both browsed the live dev server; neither submitted the form.

Mode: Operate. A bounded task with a success state, a failure state and a rate limit. All ten heuristics scored.

CONTEXT: over this session, closing sections added to home, about and packages all route here, plus the shop's and packages' unavailable-product states. This page became the catch-all for the hesitant visitor and was never itself reviewed.

TOOLING: detector exit 2, one finding — `side-tab` (border-l-4) on Alert::Component, a coloured 4px left border the craft floor bans on alerts. Not a false positive (checked against every comment span). B also caught its own tool under-reporting: read_network_requests missed cross-origin loads, so it cross-checked with the in-page performance API — that is what produced the Cloudflare finding.

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 1 | No submitting state. Tap send at 3am on bad signal and nothing changes. |
| 2 | Match System / Real World | 3 | Warm copy. Loses a point for accusing an exhausted parent of being a robot with no way out. |
| 3 | User Control and Freedom | 1 | No email address anywhere on the site. If Cloudflare is blocked there is no working way to contact Karola. |
| 4 | Consistency and Standards | 2 | h1 at text-t2, one rank below every sibling page. Turnstile card off-system in colour, radius, border, width. |
| 5 | Error Prevention | 2 | required: true never reaches the input. No native validation, no inputmode. |
| 6 | Recognition Rather Than Recall | 1 | Placeholder-only labels: typing your name destroys the field's identity. |
| 7 | Flexibility and Efficiency | 2 | autocomplete correct. No route for someone who would rather DM. |
| 8 | Aesthetic and Minimalist Design | 2 | Clean form column; five near-identical tiles, three with the same emoji. |
| 9 | Error Recovery | 0 | The error is announced to nobody, associated with nothing; the invalid field looks identical to a valid one. |
| 10 | Help and Documentation | 1 | Nothing says when a reply comes, what happens to the address, or that Cloudflare is involved. |
| **Total** | | **15/40** | **Poor (38%)** |

Lowest of any surface this session — and it is the page the whole session routed traffic to.

## Design Specificity Verdict

Authored frame, generic core, foreign object in the middle.

The shell has real decisions: a comment explaining why min-h-screen was deliberately omitted so the footer stays reachable; safe_link_url neutralising a javascript: URL the owner might paste, with a spec. Then the form is three stacked .form-control boxes with no labels, no helper text, no voice — on the surface where "people buy Karola, and they buy access to her" is supposed to be proved. Between the message field and the amber CTA sits a Cloudflare card rendering into a closed shadow root: it cannot be styled, inspected or corrected.

Verified independently: script appended in connect() with no interaction gate; site key configured locally; two requests to challenges.cloudflare.com on load with zero interaction; privacy notice never mentions Cloudflare; zero uncommented CSP policy lines; zero mailto anywhere in views or content blocks; 3 of 5 link tiles are "#"; accent-terracotta on surface 4.45:1; red-500 on ink 4.40:1; UA focus blue on surface 2.47:1 vs the system's amber at 5.98:1.

## Overall Impression

The controller is among the best-designed code in the repo — every failure path routes back into the same frame with typed content preserved and a fresh widget. The surface in front of it fails the person it was built for. The biggest issue is not a design defect: adding Turnstile silently spent a product commitment.

## Priority Issues

### [P0] Cloudflare loads on page view — the stated privacy position is false on this page
Script appended in connect(), no interaction gate. Browser makes two requests to challenges.cloudflare.com on load: api.js plus a challenge-platform endpoint receiving IP, UA and browser signals. PRODUCT.md: "A visitor who only reads the site makes no third-party request at all... Adding any third-party asset, script, embed or hosted font breaks this and requires an explicit decision."
The sharpest evidence is the README's own carve-out: "Paddle.js loads only when a checkout opens." Deferring third-party code until the visitor acts is the standard this project already set itself. Turnstile does not follow it.
Compounding: the privacy notice names Paddle, Google and hosting as the only recipients — Cloudflare absent. And there is no CSP at all.
Fix: defer loadApi() to the form's first focusin (~10 lines, restores the commitment verbatim). Otherwise make it explicit — name Cloudflare in PRODUCT.md and the privacy recipients, note it under the form, add a CSP.

### [P0] The error state is invisible, and the fix exists eight files away
No aria-live on the frame, no aria-describedby/aria-invalid on any input, .form-control.error never applied, field_with_errors unstyled, 12px error text, focus falls to <body>. Forms::Component#error_id exists specifically for this and its own comment says so; the contact form never passes it. aria-describedby appears in exactly one place in the codebase — the newsletter form. WCAG 3.3.1 and 4.1.3, both AA.

### [P1] Cloudflare unreachable => zero working contact route
No token => "could not confirm you are not a robot", forever. Ad-blockers, privacy browsers, corporate networks, JS-off all produce this. No mailto anywhere; 3 of 5 tiles are "#". The catch-all page has no fallback.

### [P1] No submitting state; a double-tap can produce a false robot error
No turbo_submits_with; the newsletter has one using an existing locale key. Second POST carries the same single-use token, Cloudflare returns duplicate, sender is told they might be a robot for a message that already arrived.

### [P2] Placeholder-only labels, ~40px targets, required never emitted
All three labels sr-only. Forms::Component accepts required: only to colour a red asterisk, applied to an invisible label.

## Persona Red Flags

Casey: taps send, sees nothing, taps again. Backgrounds the tab, returns to a wiped message. Cannot tell which field is which. The loudest amber thing on screen is the navbar's "Umów konsultację" — the action they came here to avoid.

Sam: submits and hears nothing; focus lands on <body>. On error the message is associated with no input. Success state has no role="status". The five link tiles have no focus ring — UA blue at 2.47:1 fails 1.4.11 where the system's amber gives 5.98:1. Headings skip h1 -> footer h3 with two unlabelled regions between.

3am parent: h1 says "Kontakt"; the invitation that brought them here said "Napisz do mnie". No reply timeframe. No draft persistence on a 5000-character field. After sending: one sentence, nowhere to go.

## Minor Observations

- _sent is one sentence: no heading, no role="status", no echo of the address, no onward route.
- Alert::Component sets a sentence in Baloo 2 at 26px (Display-For-Names violation) and carries the banned border-l-4.
- Latent contrast: accent-terracotta on surface 4.45:1 (passes only as large text); required asterisk red-500 on ink 4.40:1. Both just under AA.
- The legal notice has an unfilled [DO UZUPEŁNIENIA] placeholder for the data controller and it renders on /terms. NUANCE: the code flags this itself — a comment says it must be done before launch and only the owner knows what belongs there. A known TODO, not an oversight. But the GDPR Art. 13 notice is incomplete today, and when it is filled in Cloudflare needs to be in that list.
- The request spec is excellent on behaviour (15 examples incl. Turnstile action/hostname binding) and silent on accessibility — which is how the contact form came to lack what the newsletter has. Rate-limit path untested.
- Correction to Assessment A: 3 of 5 tiles are dead, not 4 — Instagram and Regulamin are real.

## Questions to Consider

1. Which decision was actually made — "add Turnstile" or "give up the no-third-party-request commitment"? They were the same decision.
2. The newsletter, a low-stakes email capture, is more accessible than the contact form — and its header says it is "the same shape as the contact form". What process produced the careful version second?
3. Product and package cards refuse to render a button into a checkout that cannot complete. Why does that principle stop at the page those dead ends route to?
4. What does _sent owe someone who just described their family's worst month to a stranger?
5. Is "Kontakt" still the right h1? It is now the answer to three different invitations, titled with an org-chart noun one type rank below every sibling.
