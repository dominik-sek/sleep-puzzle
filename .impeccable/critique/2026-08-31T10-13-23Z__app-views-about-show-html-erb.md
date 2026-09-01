---
target: app/views/about/show.html.erb
total_score: 17
max_score: 36
na_heuristics: 7
p0_count: 2
p1_count: 2
timestamp: 2026-08-31T10-13-23Z
slug: app-views-about-show-html-erb
---
Method: dual-agent (A: design review · B: detector + static evidence). Both isolated; A never saw B.

SELF-CORRECTION: DESIGN.md:261 claims "the about page uses 1.75 line-height for exactly this". It does not. `--leading-copy: 1.75` exists as a token commented "long-form (about page) paragraphs" and is applied NOWHERE in the codebase (verified). That DESIGN.md line was written from a CSS comment rather than from the view, and is false.

TOOLING: detector exit 2, one finding - a FALSE POSITIVE. The regex engine matched the literal string `<img>` inside an ERB comment at show.html.erb:13; the page never emits a bare img (it calls content_image and falls back to a div). Further: path.extname("show.html.erb") === ".erb", so even EXPLICIT file paths route to the regex engine and never the DOM engine - the DEGRADED banner cannot fire for a Rails template, and its absence is not reassurance. Findings are an undercount by construction.

Mode: Persuade. On a site positioned on "people buy Karola", this is the only surface where the product itself is on display; the visitor succeeds by deciding to trust a stranger.

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 1 | The single CTA gives no signal it hits an auth wall; the no-photo state renders at 1.43:1 and communicates nothing. |
| 2 | Match System / Real World | 3 | The page's strength - "baba z internetow", the sand joke with its :) intact. Docked: credentials are untranslated UK awarding-body jargon. |
| 3 | User Control and Freedom | 2 | stored_location_for now works. But the body offers exactly one tap target. |
| 4 | Consistency and Standards | 1 | rounded-3xl where the system mandates 16px; a Unicode glyph where astroid.svg exists; h1 at text-t2; eight amber elements; one flat band. |
| 5 | Error Prevention | 2 | Missing-photo guard is real and tested. But one blank `name` field removes the h1 and the portrait alt together. |
| 6 | Recognition Rather Than Recall | 2 | Nothing scannable; the most persuasive clause in the business is the last clause of the last paragraph in the dimmest colour. |
| 7 | Flexibility and Efficiency | n/a | Single-visit Persuade surface. |
| 8 | Aesthetic and Minimalist Design | 3 | Genuine restraint - warm palette, no cool greys, no shadows, no urgency. |
| 9 | Error Recovery | 2 | The empty-portrait state is the launch state, is tested, and is invisible. |
| 10 | Help and Documentation | 1 | Cost, duration, ages, what CBTi is - answered zero times, then it asks for a booking on faith. |
| **Total** | | **17/36** | **Poor (47%)** |

Between packages (16/36) and home (21/36). This page has the best copy in the repo and the weakest execution of it.

## Design Specificity Verdict

The copy is unmistakably this product. The composition is a generic consultant bio - worse here than anywhere, because the subject is a person who cannot be copied. Strip four CMS strings and you have square portrait left, name and role right, three paragraphs, a pull quote, a credentials box, one centred pill: the bio page of every coach with a Squarespace account.

The puzzle metaphor is in this page's own copy ("uklada sen rodzin jak puzzle", "kazda rodzina to inna ukladanka") and appears in the composition zero times. The mascot in six colourways and the avatar are absent from the page that most needs personality.

Verified independently: .trix-content is styled `text-t5 text-tan` (application.css:607) so the wrapper's text-cream at :31 is dead; U+2726 is outside both self-hosted unicode-range declarations (computed); border-strong on ink 1.43:1; surface on ink 1.12:1; border-strong on surface 1.28:1; border-input on ink 3.69:1; the sand quote appears 3x in content_blocks.yml; --leading-copy is never applied.

## Overall Impression

The best writing in the repository is on this page and the design does almost nothing with it. 140 Polish words - a 45-second read - delivered in the silhouette of a five-minute one. The four facts that constitute the entire evidentiary basis of the business are rendered smaller than the prose, in a container you cannot see. Biggest opportunity: stop hiding the proof, and stop ending on a demand.

## What's Working

1. Copy fully owner-editable in both languages, and the voice survives rather than being neutralised.
2. "Absent rather than empty" implemented AND tested in both directions.
3. Heading contract correct - real h1, real h2, no skips, a genuine blockquote. The home P0 did not recur.

## Priority Issues

### [P0] The only real proof this business has is the least visible thing on the page
Credentials at text-t6 (14px/700, smaller than the 16px prose above), panel fill 1.12:1 against the page, edge 1.43:1, heading styled identically to a footer column label. "20+ lat" is not in the panel at all - it is buried in prose, while home gives the same number a full amber band. PRODUCT.md forbids testimonials/counts/case studies, so these four facts are the entire evidence base.
Fix: heading to text-t3 cream; credential text to text-t5; edge to border-input (3.69:1); icon "astroid" for the bullet; lead with "20+ lat"; add a `note` field so Karola can gloss the acronyms.
Command: /impeccable layout app/views/about/show.html.erb

### [P0] The page about the person ends on an ask - the only one of three that still does
Final body element is an amber pill to bookings_path behind authenticate_user!. No reassurance, no alternative, no closing word, no audio catalogue. Home and packages were both reworked to close on the person; this is the introduction, so the reasoning applies with more force.
Fix: a closing ink_soft section (also fixing the flat single band) with a secondary pill to contact_path and the shop link, plus a reassurance line under the booking CTA.
Command: /impeccable layout app/views/about/show.html.erb

### [P1] A dead class means lead and body render identically
show.html.erb:31 sets text-cream but its child .trix-content is styled text-t5 text-tan (application.css:607); the child's own declaration wins. The lead renders tan, identical to the body. Same bug at home/index.html.erb:87. Nothing is bolded anywhere though .trix-content strong is styled.
Fix: a lead variant on .trix-content resolving to text-t4 text-cream at the 1.75 line-height the token already defines. Cap prose at max-w-[68ch] (currently ~84ch at 1000px).
Command: /impeccable typeset app/views/about/show.html.erb

### [P1] The launch state opens with a full-width invisible void
No photo uploaded (the state the spec asserts) renders a ~100vw dashed square at 1.43:1, first under the navbar, pushing her name below the fold. Six mascot colourways and an avatar exist for exactly this.
Fix: fall back to mascot-peach.png, or raise the frame to border-input and order the name above it on mobile.
Command: /impeccable harden app/views/about/show.html.erb

### [P2] Off-system craft cluster
rounded-3xl (24px) vs the mandated 16px - and home renders the same portrait at 8px, so one element has three radii across two pages. h1 at text-t2 where DESIGN.md reserves t1. Eight amber elements. One flat bg-ink band. No content_for :title. The glyph is U+2726, outside both self-hosted unicode-ranges, so it renders from the OS fallback at a foreign weight and baseline on every device while astroid.svg sits unused. home and packages use the SVG; about and products/show use the glyph.
Command: /impeccable polish app/views/about/show.html.erb

## Persona Red Flags

Casey: first screen is an invisible empty square. Scanning yields a first name, a sand joke, an all-caps 14px label - never learns what she does, because the job title is footer-link sized. One tap target: commit fully or leave.

Jordan: h1 is a bare first name, no surname, no discipline. "Baba z internetow" self-deprecates authority before any is established. Credentials are pure jargon to a Polish parent (OCN is a UK awarding body; CBTi unexpanded). No verification path - no issuing body, no year, no link, and no Instagram link on this page though Instagram is where visitors arrive from.

3am parent: the reason-to-believe panel is 1.12:1 on a 1.43:1 edge - at reduced brightness it is not there. Opens on a void, closes on a demand. Nothing suggests relief tonight short of paid 1:1. Earned credit: no urgency, no scarcity, no implied parental failure; the sand joke is exactly right for this reader at this hour.

## Minor Observations

- The sand quote appears 3x across two pages (home prose, home closing, about). The best line in the brand is being spent down; the home closing added the third instance.
- Divergent alt text for the same portrait: "Karola" here, "Czesc, jestem Karola" on home. Neither describes an image, and the name field does double duty as h1 and alt.
- The pull quote is a sentence in Baloo 2, against the Display-For-Names Rule - but home does the same, so it is a consistent undocumented house treatment. Sanction it in DESIGN.md or change both.
- Two of three `!` overrides on the CTA restate what variant: :primary already produces. Touch target ~51px, fine.
- Section::Component still has two dead parameters; this page passes bordered: false to no effect.
- Text contrast all passes (cream/ink 14.6, tan/ink 9.9, amber/ink 6.7). The failures are non-text: container edges and tonal steps.

## Questions to Consider

1. Delete every word and keep the layout - could a visitor tell this is about a person rather than a service? Where is the puzzle, on the page named after it?
2. Why does the joke get 26px amber Baloo 2 and the OCN certification 14px bold in an invisible box?
3. What is the cheapest next step you would accept? Following her on Instagram costs nothing and appears nowhere here.
4. "20+ lat" gets a full amber band on home and a subordinate clause on the page about her career. Which placement was decided and which inherited?
5. The spec asserts the empty-photo state and the design makes it invisible. How much confidence rests on assertions about markup that says nothing to a tired human in a dark room?
