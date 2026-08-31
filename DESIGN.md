---
name: Sleep Puzzle
description: A warm near-black interface lit by a single amber lamp, built for an exhausted parent reading on a phone at 3am.
colors:
  ink: "#211e1c"
  ink-soft: "#26221f"
  surface: "#2b2724"
  surface-dark: "#1a1817"
  border: "#35302c"
  border-strong: "#3d3833"
  border-input: "#80756b"
  cream: "#f5f0e8"
  tan: "#cfc7bc"
  taupe: "#9b948a"
  taupe-dark: "#57504a"
  accent: "#e2933e"
  accent-hover: "#ffb35e"
  accent-terracotta: "#c97a2e"
  accent-coral: "#e3987a"
  accent-gold: "#d9a441"
  gradient-hero: "#c97a2e33"
typography:
  display:
    fontFamily: "Baloo 2, sans-serif"
    fontSize: "clamp(2.25rem, 6vw, 4rem)"
    fontWeight: 700
    lineHeight: 1.08
  headline:
    fontFamily: "Baloo 2, sans-serif"
    fontSize: "clamp(1.75rem, 5vw, 2.5rem)"
    fontWeight: 700
    lineHeight: 1.2
  title:
    fontFamily: "Baloo 2, sans-serif"
    fontSize: "1.625rem"
    fontWeight: 700
    lineHeight: 1.2
  lead:
    fontFamily: "Quicksand, sans-serif"
    fontSize: "1.1875rem"
    fontWeight: 400
    lineHeight: 1.7
  body:
    fontFamily: "Quicksand, sans-serif"
    fontSize: "1rem"
    fontWeight: 500
    lineHeight: 1.6
  label:
    fontFamily: "Quicksand, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 700
    lineHeight: 1.4
    letterSpacing: "0.02em"
rounded:
  md: "6px"
  lg: "8px"
  "2xl": "16px"
  full: "9999px"
spacing:
  xs: "8px"
  sm: "16px"
  md: "24px"
  lg: "36px"
  xl: "48px"
  section: "clamp(50px, 8vw, 90px)"
  gutter: "clamp(20px, 4vw, 28px)"
components:
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.ink}"
    rounded: "{rounded.full}"
    padding: "12px 24px"
    typography: "{typography.label}"
  button-primary-hover:
    backgroundColor: "{colors.accent-hover}"
    textColor: "{colors.ink}"
  button-secondary:
    backgroundColor: "{colors.ink-soft}"
    textColor: "{colors.cream}"
    rounded: "{rounded.full}"
    padding: "12px 24px"
    typography: "{typography.label}"
  button-secondary-hover:
    backgroundColor: "{colors.ink-soft}"
    textColor: "{colors.cream}"
  button-outline:
    backgroundColor: "transparent"
    textColor: "{colors.cream}"
    rounded: "{rounded.full}"
    padding: "12px 24px"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.cream}"
    rounded: "{rounded.lg}"
    padding: "8px 14px"
  card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.cream}"
    rounded: "{rounded.2xl}"
    padding: "20px 16px"
  input:
    backgroundColor: "{colors.ink-soft}"
    textColor: "{colors.cream}"
    rounded: "{rounded.lg}"
    padding: "8px 12px"
    typography: "{typography.body}"
  nav-link:
    backgroundColor: "transparent"
    textColor: "{colors.cream}"
    rounded: "{rounded.md}"
    padding: "8px 8px"
    typography: "{typography.body}"
  step-numeral:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.ink}"
    rounded: "{rounded.full}"
    height: "64px"
    width: "64px"
    typography: "{typography.title}"
---

# Design System: Sleep Puzzle

## Overview

**Creative North Star: "The Piece That Fits"**

The product's name is not decoration — it is the design brief. Karola describes her
work as assembling a family's sleep like a puzzle, piece by piece, and the interface
is built the same way: from discrete, self-contained, softly-cornered pieces that
tessellate into something whole. A package is a piece. A product is a piece. A step
in the process is a piece. Nothing floats, nothing is loose, nothing is missing —
and when a piece has nothing to say, it is absent rather than empty.

The material is soft, tactile, generous and playful. The ground is a warm near-black
(`ink`, #211e1c) — brown-leaning, never blue-leaning, never a true black — and every
surface above it is another warm neutral a few points lighter. Corners are large
(16px on containers) and actions are fully round. Baloo 2's rounded terminals and the
mascot's presence set a register that is closer to a well-made soft toy than to a
clinical app. The whole thing is lit by exactly one warm light: `accent`, a lamp
amber, which is the only saturated colour in the system.

This restraint is not minimalism, it is care. The visitor is an exhausted parent
reading on a phone in a dark room, and the design's first job is to be legible and
calm at that hour. Softness is how competence is expressed here: generous padding,
thumb-sized targets, a palette that does not glare, and a single point of light per
screen telling them where to go next.

**Key Characteristics:**

- Warm near-black ground; brown-neutral throughout, no cool greys, no true black.
- One saturated colour in the entire system: lamp amber. Everything else is a neutral.
- Depth by tonal layering and hairlines, not by shadow.
- Large radii: 16px pieces, fully-round actions.
- Two typefaces, both rounded: Baloo 2 for display, Quicksand for everything read.
- Self-hosted fonts and zero third-party assets — a design constraint, not just an ops one.
- Built phone-first for a tired one-handed reader.

## Colors

A single-accent system: sixteen warm neutrals arranged from near-black to cream,
lit by one amber. There is no secondary or tertiary accent role — the coral and gold
below are tints of the same light, not competing voices.

### Primary

- **Lamp Amber** (`accent`): The system's one voice. Every primary action, every list
  marker, every focus ring, every link, and the numerals on the process steps. It is
  a light source rather than a fill — it appears against ink, never against another
  saturated colour.
- **Lamp Amber Bright** (`accent-hover`): The hover and active state of Lamp Amber.
  Brighter and slightly pinker, so a hovered control reads as *turned up* rather than
  as a different colour.
- **Terracotta** (`accent-terracotta`): The deeper, dustier amber used as the hairline
  border on primary buttons (at 30% alpha) and as the source colour of the hero glow.
  It bounds the light; it is not a fill colour on its own.
- **Coral** (`accent-coral`): Reserved for the secondary tier of accent marks — the
  astroid bullets on a package's "also included" list, which must read as subordinate
  to the amber check marks above them.
- **Gold** (`accent-gold`): Declared and available for a warmer, less orange accent
  moment. Currently unused; use it deliberately or not at all.

### Neutral

Surfaces, darkest to lightest — the whole depth model lives in this ladder:

- **Ink** (`ink`): The page. A warm near-black with a brown cast. The default section
  background and the text colour that sits on amber.
- **Ink Soft** (`ink-soft`): The alternating section band, and the resting fill of
  inputs and secondary buttons. Barely a step up from Ink — the difference is felt
  more than seen, which is the point.
- **Surface** (`surface`): Cards and pieces. The one surface that reads as lifted
  off the page.
- **Surface Dark** (`surface-dark`): The footer and the navbar — the chrome that
  bookends the page sits *below* it, not above.

Borders, faint to firm:

- **Hairline** (`border`): Section dividers and the footer's rules. The quietest
  separation in the system.
- **Piece Edge** (`border-strong`): The border of every card. This is what makes a
  piece read as a discrete object against `surface`.
- **Field Edge** (`border-input`): Input rings, checkboxes, and the outline of
  secondary pills. The only border meant to be clearly visible, and the value is
  set by that job: it clears WCAG 1.4.11 (3:1) against all four surfaces, so it
  is the correct token for a **control boundary** and the wrong one for a
  container edge or a text colour — those are `border-strong` and `taupe-dark`.

Text, brightest to faintest:

- **Cream** (`cream`): Primary reading colour and every heading on a dark ground.
  Warm off-white — never `#ffffff`.
- **Tan** (`tan`): Body copy in a supporting role — subtitles, descriptions, card
  paragraphs, footer links.
- **Taupe** (`taupe`): Muted metadata, uppercase micro-labels, durations, placeholders.
- **Taupe Dark** (`taupe-dark`): Faint text only — the copyright line, the borders of
  de-emphasised pills. Below body-text contrast; never use it for anything a visitor
  must read.

### Named Rules

**The One Lamp Rule.** There is one light source per screen. Lamp Amber marks the
single most important action in a view and the small marks that guide the eye to it —
nothing else. Two amber buttons competing in one viewport means one of them is wrong.

**The Warm Neutral Rule.** Every neutral in this system leans brown. A cool grey
(`neutral-*`, `zinc-*`, `slate-*`) or a pure `#fff` / `#000` anywhere in the public
site is drift, not a choice.

**The No Dark Mode Rule.** There is no light mode to toggle away from. The system is
dark by construction, so `dark:` variants are meaningless here — a `dark:` prefix in
this codebase is a leftover from the component scaffold, not a feature.

## Typography

**Display Font:** Baloo 2 (with `sans-serif`), variable, weights 400–800
**Body Font:** Quicksand (with `sans-serif`), variable, weights 300–700

Both are self-hosted from `app/frontend/fonts` and subset into `latin` and
`latin-ext`; the extended subset is mandatory, because Polish needs ą/ć/ę/ł/ń/ś/ź/ż.

**Character:** Two rounded geometric sans faces, deliberately paired rather than
contrasted. Baloo 2 is warm, heavy and slightly bouncy — it carries the personality
and the humour. Quicksand is the same roundness at low contrast and light weight,
which keeps long Polish sentences readable without the page ever turning severe.
The pairing has no serif, no condensed face and no monospace: nothing in this system
is meant to look technical.

### Hierarchy

- **Display** (Baloo 2, 700, `clamp(2.25rem, 6vw, 4rem)` / 1.08): The one page title.
  Hero headlines and page H1s only.
- **Headline** (Baloo 2, 700, `clamp(1.75rem, 5vw, 2.5rem)` / 1.2): Section headings.
  The most common large type on the site.
- **Title** (Baloo 2, 700, 26px / 1.2): Card and subsection titles — a package's name,
  a product's name, the wordmark in the navbar and footer.
- **Lead** (Quicksand, 400, 19px / 1.7): The paragraph directly under a Display or
  Headline. Lighter than body on purpose; it is read at a glance, not studied.
- **Body** (Quicksand, 500, 16px / 1.6): All reading copy. Medium rather than regular,
  because 400-weight Quicksand on a dark ground goes thin. Constrain long-form measure
  to roughly 65–75ch — the about page uses 1.75 line-height for exactly this.
- **Label** (Quicksand, 700, 14px / 1.4, +0.02em): Micro-labels, footer links, button
  text, and the uppercase eyebrows on cards ("Dla kogo", "Co otrzymujecie").

### Named Rules

**The Display-For-Names Rule.** Baloo 2 is for things that are *named* — headings,
titles, wordmarks, durations, step titles. Anything the visitor reads as a sentence
is Quicksand. Never set a paragraph in Baloo 2.

**The Uppercase Ceiling Rule.** Uppercase is only ever applied at Label size, in
Taupe, as a category eyebrow. There is no uppercase heading anywhere in this system,
and there should not be — Baloo 2's roundness turns hostile at scale in caps.

**The Two-Language Rule.** Every type decision must survive Polish. Polish words run
noticeably longer than their English equivalents, so headline sizes are set in
`clamp()` and no label is allowed to depend on fitting a fixed-width box.

## Layout

A single centred column, capped at **1240px**, with a horizontal gutter of
`clamp(20px, 4vw, 28px)`. The page is a vertical stack of full-bleed sections whose
backgrounds alternate `ink` / `ink-soft`; only the inner content is constrained,
so the tonal bands run edge to edge and give a long page its rhythm.

**Vertical rhythm** is carried by three section paddings, and nothing else should
invent a fourth: standard `clamp(50px, 8vw, 90px)`, compact `clamp(12px, 2vw, 28px)`
for thin strips like the stats bar, and none for sections that manage their own.

**Spacing** follows a 4px base, and in practice six steps do all the work: 8px
(inside a label group), 16px (between related elements), 24px (between blocks within
a piece and between cards in a grid), 36px, and 48px for the widest column gaps.

**Responsive behaviour** is phone-first and mostly binary. Card grids run
`1 → 2 (md) → 3 (lg)`; two-column layouts stack below `md`; the navbar collapses to
a hamburger below `lg`. Breakpoints are Tailwind's defaults (sm 640, md 768, lg 1024,
xl 1280). Where a list is owner-managed and can change length, the row uses `flex-1`
distribution rather than a fixed column count, so a fourth process step divides the
row instead of breaking it.

**Density is low and deliberate.** Cards are `gap-6` internally, sections are
`gap-8`. Nothing is packed. This is the single most load-bearing accommodation for
the tired reader, and tightening it to fit more above the fold is the wrong trade.

### Named Rules

**The Alternating Band Rule.** Consecutive sections alternate `ink` and `ink-soft`.
Two adjacent sections on the same background is a seam that disappears, and a long
page then reads as one undifferentiated scroll.

**The Full-Bleed Band, Capped Content Rule.** Backgrounds always span the viewport;
content never exceeds 1240px. A section that constrains its own background is wrong.

## Elevation & Depth

Depth is **tonal, not cast**. Four warm surfaces stack from `surface-dark` (chrome)
through `ink` (page) and `ink-soft` (alternate band) to `surface` (pieces), and
hairline borders — `border-strong` on cards, `border` on dividers — do the actual
work of separating one thing from another. On a near-black ground a grey drop shadow
is invisible, so the system does not rely on one.

Shadows survive for exactly one job: **things that float above the page.** Dropdowns,
the mobile menu panel, toasts and modals may cast, because they genuinely overlap
content and need to be read as temporarily on top of it. Nothing that sits *in* the
page — no card, no section, no button — earns a shadow.

### Shadow Vocabulary

- **Overlay** (`box-shadow: 0 10px 30px rgba(0, 0, 0, 0.45)`): Menus, dropdowns,
  toasts, dialogs. Deep and soft enough to separate from ink without a visible edge.

### Named Rules

**The Flat Page Rule.** In-page surfaces are flat. If a piece needs to feel lifted,
raise its tone (`ink` → `surface`) or firm up its border — never add a shadow.

**The Glow Is Not A Shadow Rule.** The hero's radial `gradient-hero` wash is light
emitted by the mascot, not depth cast by it. Radial warmth is available as an
atmospheric device; it never doubles as an elevation cue.

## Shapes

The form language is **soft, generous and thumb-friendly** — the silhouette of every
element should suggest something safe to touch when you are not fully awake.

- **Pieces** (cards, product tiles, package cards) carry a **16px** radius (`2xl`)
  with a `border-strong` hairline. This is the system's signature shape and the
  literal expression of the puzzle metaphor.
- **Actions** are **fully round** (`rounded-full`). Every primary and secondary CTA
  on the public site is a pill; a square-cornered button is off-system.
- **Fields and small chrome** use **8px** (`lg`) — inputs, images, the mobile menu's
  rows. Just enough softening not to read as a rectangle.
- **Menu rows and nav triggers** use **6px** (`md`), the smallest radius in use.
- **Marks are circles.** The process-step numerals are 64px amber discs; the mascot,
  the avatar and the hero glow are all circular.

The one non-round form in the system is the **astroid** — a four-pointed concave
star used as the accent bullet on stat lists and package add-ons. It is the only
piece of geometry with points, which is precisely what makes it work as a marker.

### Named Rules

**The Pill-For-Action Rule.** If it is the thing you want the visitor to press, it is
a pill. Radius signals affordance in this system: round means *do*, 16px means *read*.

## Components

### Buttons

- **Shape:** Fully round pills (`rounded-full`, 9999px) for public CTAs; 8px
  (`rounded-lg`) for utility buttons inside dense UI.
- **Primary:** Lamp Amber fill with Ink text and a Terracotta hairline at 30% alpha
  (`border border-accent-terracotta/30`), 12px × 24px padding, Label typography at
  weight 700. This is the "do the thing" button — booking, buying, submitting.
- **Secondary:** Ink Soft fill, Cream text, Field Edge border. Sits beside a primary
  without competing with it.
- **Outline / Ghost:** Transparent, Cream text; ghost drops the border. For tertiary
  and in-card actions.
- **Destructive:** Red fill, Cream text. Rare and staff-facing; it is the one place
  a non-warm hue is permitted, because a delete confirmation should not look cosy.
- **Hover:** Primary brightens to `accent-hover`; every other variant fills to
  `ink-soft`. Transitions are 100ms `ease-in-out` — fast, because a hover is feedback,
  not an animation.
- **Focus:** `outline-2 outline-offset-2` in Lamp Amber on `:focus-visible`. This is
  a WCAG requirement in this project, not a nicety; never remove it.
- **Disabled:** 50% opacity and `not-allowed`. The system has no separate disabled fill.

### Cards / Containers

- **Corner Style:** 16px (`rounded-2xl`).
- **Background:** `surface` — the only element that uses it.
- **Border:** A single `border-strong` hairline. Together with the tonal step, this
  is the entire depth treatment.
- **Shadow Strategy:** None. See Elevation & Depth.
- **Internal Padding:** 20px × 16px at the default (`md`) size, rising to 24px at
  `lg`; content inside a card is separated by 24px (`gap-6`).
- **Behaviour:** Cards in a grid stretch to equal height, and a card's CTA is pinned
  to the bottom with `mt-auto` so a row of CTAs aligns regardless of how much copy
  each piece carries. This is what keeps a row reading as one comb rather than a ragged edge.

### Inputs / Fields

- **Style:** Ink Soft fill, no border — an inset `ring-1` in Field Edge instead —
  8px radius, Cream text, Taupe placeholder, 8px × 12px padding.
- **Focus:** The ring thickens to `ring-2` in Lamp Amber. The field lights up; it
  does not move or resize.
- **Readonly:** Surface Dark fill with Tan text — visibly inert but still selectable,
  for values that come from the account and cannot be edited.
- **Error:** Red 400 border and ring. The only non-warm state colour in a form.
- **Sizing:** 16px on mobile, dropping to 14px at `sm` and above. The mobile size is
  deliberate — anything under 16px makes iOS Safari zoom the viewport on focus.

### Navigation

- **Bar:** Surface Dark with a `border-strong` bottom hairline, sticky. The wordmark
  `sleep.puzzle` is set in Title-size Baloo 2 in Cream.
- **Items:** Body-size Quicksand in Cream, 6px radius, filling to `ink-soft` on hover.
- **Mobile:** Below `lg` the items collapse into a hamburger panel; the panel repeats
  every bar action (cart, account, language, sign-out) so nothing is reachable only on
  desktop, and it ends with a full-width primary pill for the booking CTA.
- **Footer:** Surface Dark, a `repeat(auto-fit, minmax(180px, 1fr))` grid so the link
  columns pack themselves from one column to four without named breakpoints. Column
  headings are uppercase Label in Lamp Amber; links are Label in Tan, going amber on hover.

### Astroid Bullet (signature)

The four-pointed concave star (`astroid.svg`), rendered at 14–16px in Lamp Amber for
primary marks and Coral for secondary ones. It is the system's punctuation: it opens
each stat in the home page strip and each add-on in a package card. Use it where a
generic disc bullet would go; it is the cheapest way for a new surface to read as
part of this system.

### Step Numeral (signature)

A 64px Lamp Amber disc with the step's number in Ink at Title size, centred above a
step title and description. The numbering follows display order rather than being
stored, so the owner can reorder or add a step in the admin panel without renumbering
anything.

## Do's and Don'ts

### Do:

- **Do** keep every neutral warm and brown-leaning. `ink` (#211e1c) is the floor of
  the system; `cream` (#f5f0e8) is the ceiling.
- **Do** give each screen exactly one Lamp Amber primary action. Its rarity is what
  makes it work.
- **Do** alternate section backgrounds `ink` / `ink-soft` down a long page.
- **Do** reach for the astroid mark instead of a generic bullet — it is the fastest
  signature in the system.
- **Do** keep body text at 16px minimum on mobile, and inputs at 16px, so iOS Safari
  does not zoom on focus.
- **Do** set headline sizes in `clamp()` and let labels wrap. Polish runs long.
- **Do** pin card CTAs with `mt-auto` so a row of pieces aligns at the bottom.
- **Do** preserve a visible `focus-visible` outline in Lamp Amber on every interactive
  element. WCAG 2.1 AA is binding on this project.
- **Do** let `Card::Component` supply its own edge. Every variant now resolves to
  system tokens (`border-strong` edge, `ink-soft` well and footer, `border`
  dividers), so a call site that writes `border-border-strong!` is re-stating the
  default and should drop it. `hoverable:` lifts the border to `border-input`
  rather than casting a shadow, per the Flat Page Rule.
- **Do** keep fonts and every other asset self-hosted. The site's no-consent-banner
  position depends on making zero third-party requests.

### Don't:

- **Don't** use Tailwind's cool neutrals (`neutral-*`, `zinc-*`, `slate-*`, `gray-*`),
  `bg-white`, or pure black anywhere on the public site.
- **Don't** write `dark:` variants. This system has no light mode; a `dark:` prefix
  here is dead code that will never apply.
- **Don't** use `Buttons::Component`'s `style: :fancy` variants. They are unconverted
  scaffold — grey-and-white gradient buttons from a generic component library that
  bear no relationship to this design system. The `:basic` variants are the real ones.
- **Don't** use the bare `select`, `[type="checkbox"]` or `[type="radio"]` styles from
  `application.css` on a public page without converting them first. They are still
  white-on-neutral-300 scaffold and will punch a hole in the warm-dark world.
- **Don't** add drop shadows to in-page elements. Raise the tone or firm the border.
- **Don't** set a paragraph in Baloo 2, and don't set an uppercase heading in it at all.
- **Don't** introduce a second saturated colour. Coral and gold are tints of the one
  lamp, not new accents.
- **Don't** use Taupe Dark for anything the visitor needs to read.
- **Don't** tighten the spacing to fit more above the fold. The low density is the
  accommodation for the exhausted reader, not slack to be reclaimed.
- **Don't** add urgency, scarcity, countdowns or red badges to commerce surfaces. The
  visitor is already frightened; this system never trades on that.
