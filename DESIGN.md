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
  gradient-hero: "#C97A2E33"
  red-300: "oklch(80.8% 0.114 19.571)"
  red-400: "oklch(70.4% 0.191 22.216)"
  red-500: "oklch(63.7% 0.237 25.331)"
  red-600: "oklch(57.7% 0.245 27.325)"
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
  lead-copy:
    fontFamily: "Quicksand, sans-serif"
    fontSize: "1.1875rem"
    fontWeight: 400
    lineHeight: 1.75
  body-copy:
    fontFamily: "Quicksand, sans-serif"
    fontSize: "1rem"
    fontWeight: 500
    lineHeight: 1.75
rounded:
  md: "6px"
  lg: "8px"
  "2xl": "16px"
  "3xl": "24px"
  full: "9999px"
spacing:
  xs: "8px"
  sm: "16px"
  md: "24px"
  lg: "32px"
  xl: "48px"
  section: "clamp(50px, 8vw, 90px)"
  section-compact: "clamp(12px, 2vw, 28px)"
  gutter: "clamp(20px, 4vw, 28px)"
components:
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.ink}"
    rounded: "{rounded.full}"
    padding: "16px 24px"
    typography: "{typography.label}"
  button-primary-hover:
    backgroundColor: "{colors.accent-hover}"
    textColor: "{colors.ink}"
  button-secondary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.cream}"
    rounded: "{rounded.full}"
    padding: "16px 24px"
    typography: "{typography.label}"
  button-secondary-hover:
    backgroundColor: "{colors.ink-soft}"
    textColor: "{colors.cream}"
  button-outline:
    backgroundColor: "transparent"
    textColor: "{colors.cream}"
    rounded: "{rounded.full}"
    padding: "12px 24px"
  button-outline-hover:
    backgroundColor: "{colors.ink-soft}"
    textColor: "{colors.cream}"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.cream}"
    rounded: "{rounded.lg}"
    padding: "8px 14px"
  button-ghost-hover:
    backgroundColor: "{colors.ink-soft}"
    textColor: "{colors.cream}"
  button-destructive:
    backgroundColor: "{colors.red-600}"
    textColor: "{colors.cream}"
    rounded: "{rounded.lg}"
    padding: "8px 14px"
  button-destructive-hover:
    backgroundColor: "{colors.red-500}"
    textColor: "{colors.cream}"
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
  nav-link:
    backgroundColor: "transparent"
    textColor: "{colors.cream}"
    rounded: "{rounded.md}"
    padding: "8px 12px"
    height: "44px"
  disclosure:
    backgroundColor: "transparent"
    textColor: "{colors.accent}"
    rounded: "{rounded.md}"
    typography: "{typography.label}"
  offer-puzzle:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.cream}"
    rounded: "{rounded.3xl}"
    padding: "24px"
---

# Design System: Sleep Puzzle

## Overview

**Creative North Star: "The Piece That Fits"**

The product's name is the design brief. Karola describes her work as assembling a
family's sleep like a puzzle, piece by piece. The interface follows that metaphor:
discrete, softly cornered pieces, generous space, and a visible connection between
related choices. A package, a product and a disclosure each hold a manageable part
of the story. Empty optional sections disappear; catalogue categories retain a
short empty state so their navigation targets remain useful.

The material is soft, tactile, generous and playful. The ground is a warm near-black,
brown-leaning rather than blue-leaning, with progressively lighter warm surfaces.
Baloo 2's rounded terminals and the mascot establish warmth; the owner's portrait
provides a human presence. Amber is the dominant light. Cream and tan carry the
reading, while borders and small accents guide the eye.

The intended reader is an exhausted parent on a phone in a dark room. Calm,
legibility, large targets and short previews are practical accommodations. Long
copy remains available through disclosure instead of dominating the first read.

**Key Characteristics:**

- Warm near-black ground with brown neutrals and cream text.
- One dominant amber accent, with related tones for supporting status messages.
- Depth primarily through tonal layering and hairlines.
- Soft containers, pill CTAs and an interlocking puzzle joint.
- Baloo 2 for named headings and prices; Quicksand for reading and controls.
- Self-hosted fonts and assets as a durable privacy constraint.
- Phone-first spacing, disclosure and recovery paths.

This reference describes the current implementation. Sources are the theme and
utilities in `app/frontend/entrypoints/application.css`, shared ViewComponents,
and public views. Legacy scaffold and retained hidden sections are distinguished
from active patterns below. It follows the [DESIGN.md format](https://raw.githubusercontent.com/google-labs-code/design.md/main/docs/spec.md).

## Colors

A single dominant amber sits within a warm neutral ladder. Related coral, gold and
terracotta tones support meaning; they do not create additional competing brands.
Token values in the frontmatter are normative.

### Primary

- **Lamp Amber** (`accent`): Primary actions, links, focus outlines, selected calendar
  dates, check marks and package titles.
- **Lamp Amber Bright** (`accent-hover`): Brighter hover feedback for actions and links.
- **Terracotta** (`accent-terracotta`): Primary button hairline at 30% alpha and warning
  titles. The retained hero glow also derives from this hue.
- **Coral** (`accent-coral`): Error titles and editorial warnings in the admin tools.
- **Gold** (`accent-gold`): Success titles in the shared alert component.
- **Hero Glow** (`gradient-hero`): Declared translucent atmosphere token. Used in the
  retained, hidden home composition; the active portrait hero has no glow.

### Neutral

- **Surface Dark** (`surface-dark`): Navbar, footer, dropdowns and inert field fill.
- **Ink** (`ink`): Page floor, secondary buttons and text on amber.
- **Ink Soft** (`ink-soft`): Alternating bands, inputs, wells and secondary hover fill.
- **Surface** (`surface`): Cards, package dialogs and the joined offer pieces.
- **Hairline** (`border`): Quiet dividers and dropdown edges.
- **Piece Edge** (`border-strong`): Container boundaries and section-band rules.
- **Field Edge** (`border-input`): Visible control boundaries, input rings and
  secondary/outline button edges. Keep container and control edges distinct.
- **Cream** (`cream`): Primary text and most headings.
- **Tan** (`tan`): Supporting reading copy.
- **Taupe** (`taupe`): Readable muted metadata, helper text and placeholders. The
  footer copyright also uses this token.
- **Taupe Dark** (`taupe-dark`): Inactive slot text. Avoid it for required reading.

### Functional exceptions

The shared destructive button uses Tailwind's **Red 600**, **Red 500** on hover and
**Red 300** at 30% alpha on its edge. Form errors use **Red 400** rings. These are
functional states, not additional marketing accents. Their source OKLCH values are
preserved in the frontmatter.

### Named Rules

**The One Lamp Rule.** Amber identifies the principal action or choice. A package
row may repeat the same booking action on each card; avoid competing action types
with equal amber emphasis in the same group.

**The Warm Neutral Rule.** Public content surfaces use the warm neutral tokens.
Pure black backdrops and vendor viewer chrome are overlay treatments, not a new
page palette. Cool-neutral scaffold is not a model for new public components.

**The No Dark Mode Rule.** The public system is dark by construction. Root
`color-scheme: dark` also styles native controls. Existing scaffold `dark:` classes
do not establish a supported light theme.

## Typography

**Display Font:** Baloo 2, `sans-serif`, variable weights 400–800.
**Body Font:** Quicksand, `sans-serif`, variable weights 300–700.

Both are self-hosted from `app/frontend/fonts`, with `font-display: swap` and separate
latin/latin-ext subsets. Keep the extended subset for Polish characters.

The rounded pairing gives the headings personality without changing register for
long copy. Font-family is separate from the bundled `text-t1`–`text-t6` utilities;
headings explicitly opt into `font-display`.

### Hierarchy

- **Display / t1** (Baloo 2, 700, 36–64px / 1.08): Hero and page titles. Semantic heading
  level follows the document outline, not the size utility.
- **Headline / t2** (Baloo 2, 700, 28–40px / 1.2): Section headings.
- **Title / t3** (Baloo 2, 700, 26px / 1.2): Card names, prices, subsection titles and
  the wordmark. Prices use tabular numerals.
- **Lead / t4** (Quicksand, 400, 19px / 1.7): Supporting introductions.
- **Body / t5** (Quicksand, 500, 16px / 1.6): Summaries, benefits, duration sentences,
  booking instructions and the comparison-image hint.
- **Label / t6** (Quicksand, 700, 14px / 1.4, +0.02em): Card categories, compact
  actions and footer links. Labels are not a substitute for reading text.
- **Rich lead** (`trix-lead`, 19px / 1.75): Styles the nested `.trix-content` itself.
  Defaults to cream for editorial prose, such as the about-page biography.
- **Rich body** (`trix-copy`, 16px / 1.75): Expanded prose. Base `.trix-content` remains
  body size; paragraphs have a 16px bottom gap except the last paragraph.

Public page headers use `.page-title` (Display / t1, cream) and `.page-subtitle`
(Lead / t4, tan). These roles share font family, size, weight, line height and color
across template copy, plain CMS fields and rich CMS fields. Action Text wrappers
and headings inside a subtitle inherit the role; bold emphasis and links remain
available. Keep spacing and width on the view, and reserve `.trix-lead` for
editorial paragraphs rather than page subtitles.

Common leads are constrained to `max-w-2xl` (672px), closing prose to `max-w-xl`
(576px). Aim for a comfortable 65–75 characters in wider reading blocks. Headings
use balanced wrapping where implemented; `text-pretty` improves prose line endings.

### Named Rules

**The Display-For-Names Rule.** Baloo 2 names things: headings, prices and wordmarks.
Quicksand explains them. A sentence such as "Support lasts 5 weeks" is body copy,
not a display duration badge.

**The Uppercase Ceiling Rule.** Authored category labels use Label size, in taupe or
amber. Keep editorial headings in natural case. Owner-supplied package names can
retain their existing uppercase spelling; do not silently rewrite their content.

**The Two-Language Rule.** Every layout must allow Polish expansion and wrapping.
The English route can intentionally fall back to Polish owner content. Test the
actual text instead of assuming a short translated label.

## Layout

Full-width section backgrounds contain centred content. `Section::Component` caps
its padded wrapper at 1240px. Its horizontal gutter is fluid (20–28px). Some bespoke
sections cap the inner column after applying outer padding; follow the relevant
existing component rather than imposing an identical inner width on every route.

The three section utilities are standard (50–90px vertical), compact (12–28px) and
none (horizontal gutters only). Within a section, 8px groups labels and copy, 16px
joins related content, 24px separates card blocks and grid items, 32px separates
section children, and 48px creates larger pauses. Use the underlying 4px scale for
smaller optical adjustments.

### Responsive patterns

- Tailwind defaults: `sm` 640px, `md` 768px, `lg` 1024px, `xl` 1280px.
- Package overview: one column on phones, two from `sm`, three from `lg` when three
  or more packages exist. One package caps at 376px, two at 776px, and larger sets
  at 1176px. The grid gap is 24px.
- Home hero, joined offer choices and paired reading blocks become columns at `md`.
- Calendar/date and time selection remain stacked until `lg`.
- The navbar switches to the hamburger presentation below `lg`.
- Footer columns use `repeat(auto-fit, minmax(180px, 1fr))`; the container remains
  bounded by the viewport.

Package cards stretch within a row. Actions sit at the bottom with `mt-auto`; card
names reserve two title lines from `sm` so duration and price baselines align with
the current names. Longer owner copy can grow naturally. On narrow phones below
400px the calendar borrows the 20px page gutters so seven 44px targets fit without
clipping or shrinking.

### Named Rules

**The Tonal Band Rule.** Alternate ink and ink-soft to separate distinct page groups.
Optional sections can change the sequence; adjacent ink sections are valid when
they belong to the same flow, as on the package overview and calendar.

**The Full-Bleed Band, Capped Content Rule.** Backgrounds span the viewport; readable
content stays in a capped wrapper with fluid gutters. Avoid horizontal scrolling
in public reading and purchase paths.

## Elevation & Depth

Depth primarily comes from the four warm surfaces and hairline edges. Default cards
cast no shadow; `hoverable:` firms their border and `clickable:` can change their
fill. Overlapping menus and dialogs use the shared shadow utilities.

### Shadow Vocabulary

- **Overlay / shadow-xl** (`0 20px 25px -5px rgb(0 0 0 / 10%), 0 8px 10px -6px rgb(0 0 0 / 10%)`):
  Dropdowns, package dialogs and the calendar's processing overlay.
- **Field / shadow-xs** (`0 1px 2px 0 rgb(0 0 0 / 5%)`): Small field depth beneath the
  inset control ring.
- **Testimonial** (`0 12px 36px rgba(0,0,0,0.12)`): A subtle existing exception on the
  testimonial card variant. It does not change the default card treatment.

Package dialogs dim the page with a 65% black backdrop; the staff calendar dialog
uses 55%. These overlays protect the reading focus. The declared hero glow remains
in the retained hidden composition; it is not a feature of the active hero.

### Named Rules

**The Flat Page Rule.** Default in-page pieces use tone and edge to separate content.
Do not add a drop shadow simply to make a card seem more important. Existing field
and testimonial exceptions have specific component roles.

**The Glow Is Not A Shadow Rule.** The retained hero glow is atmospheric light,
not an elevation cue. Do not infer a glow requirement for new sections.

Motion is feedback: buttons and calendar states use 100ms, the puzzle seam 150ms,
menus 200ms and the shared accordion 300ms. Native reading disclosures open directly.
Reduced-motion styles remove navbar and puzzle transitions; custom viewer zoom uses
the duration resolved by PhotoSwipe, including zero for reduced motion/slow updates.
The dashboard arrival highlight runs only without a reduced-motion preference.

## Shapes

- **Standard pieces**: 16px corners and a Piece Edge hairline.
- **Portraits and joined offers**: 24px outer corners. The offer pair shares one
  edge, with an 80px SVG puzzle joint that rotates its layout between stacked and
  side-by-side presentations.
- **Public CTAs**: Fully rounded pills. Utility buttons and form controls use 8px
  corners; navigation and disclosure triggers use 6px corners.
- **Avatars**: Circular crops with initials or image fallbacks.
- **Marks**: Lucide check/arrow/chevron icons. The astroid remains in the about-page
  qualification list and retained home sections, not the current package benefits.

### Named Rules

**The Pill-For-Action Rule.** Prominent public CTAs use pills. Smaller menu, disclosure
and calendar controls retain their own compact form; not every interactive element
needs a pill silhouette.

## Components

### Buttons

Warm, direct controls with a clear emphasis step.

- **Primary:** Amber fill, ink text, Terracotta edge at 30% alpha.
- **Secondary:** Ink fill, cream text, Field Edge border; ink-soft hover fill.
- **Outline:** Transparent fill, cream text and Field Edge border; ink-soft on hover.
- **Ghost:** Transparent with no border; ink-soft on hover.
- **Destructive:** Red 600 fill, cream text and a Red 300 edge at 30% alpha; Red 500 hover.
- **Public sizing:** Package and recovery actions use Label typography (14px, 700)
  with 16px × 24px padding. The package details action uses 12px × 24px and a 48px
  minimum height. Long closing CTAs can wrap. Preserve at least 44px touch targets.
- **Utility sizing:** The component's default `md` is 8px × 14px, 14px text at weight
  500 and 8px corners. Public call sites opt into pills and stronger labels.
- **Focus:** 2px amber outline, normally offset 2px; the card details trigger uses 4px.
- **States:** 100ms easing. Disabled native buttons use 50% opacity and `not-allowed`.
  Loading replaces the icon with a spinner and disables the control. Links retain
  native navigation semantics; `aria-disabled` alone does not suppress navigation.

### Cards / Containers

Readable pieces with a quiet, firm edge.

Default `Card::Component` uses surface fill, 16px corners and a Piece Edge border.
A well uses ink-soft. Default body padding is 20px vertically / 16px horizontally
on phones and 24px on all sides from `sm`; large bodies use 24px then 32px. Footer
fill is ink-soft, dividers are Hairline. Use the component's edge rather than
repeating it at call sites. `stretch_body: true` enables equal-height overview cards.

Audio catalogue cards use 16px corners, a surface fill, 24px padding and a compact
product icon beside the name. A short 16px description preview leads to the full
product page; price and cart state stay together near the bottom. Category pages
use H2 product names; the grouped shop uses H2 section names and H3 product names.
Category grids keep their own cap (320px for one, 664px for two, 1008px for three),
with 24px card gaps. Empty audio categories retain their anchors
and a short owner-editable message. The category pages cap their inner content at
1080px. `/audioprocesses` places the product grid 32px after the introduction, with
no Format/Access facts block. `/stories` places its grid 24px after the introduction
and shared delivery facts below the recordings. The empty message
renders at body size (`text-t5`) and the `Sklep` return link at body size in amber
(`text-t5`, `text-accent`) with a 44px minimum touch target; that link is shown on
both category pages in both the empty and populated states.

The shop index follows Option F (local reference: `mockups/products-shop-option-f`). Packages
lead: the second published package is the spotlight (the first when there is only
one), with all others as compact rows. Each shows its first card highlight,
existing localized duration and Paddle price. Only the spotlight has a filled
action; unavailable prices keep a neutral details link. The shop reuses the
opening collaboration paragraph, leaving images and full prose on `/packages`.

The audioprocess shelf uses a full-width row for one item, equal cards for two or
three on desktop (stacked on phones), and a native scroll-snap rail from four.
Arrows appear only when the rail overflows and honour reduced motion. Descriptions
clamp to three lines, and cart/account states retain the shared Turbo controls
with outline styling. Stories use a compact strip when empty and retain cards
when populated. Category chips are removed; existing focusable fragments keep
their 96px scroll margin, and category-page links remain. Navbar, footer and the
cart pill keep their existing components.

### Inputs / Fields

Inset and legible rather than bright white.

`.form-control` uses ink-soft fill, cream text, taupe placeholder, 8px corners,
8px × 12px padding, a 1px inset Field Edge ring and the small field shadow. Focus
thickens the ring to 2px amber. Text is 16px/24px on phones, 14px/24px from `sm`.
Readonly uses surface-dark and tan; disabled also uses surface-dark. Errors use a
Red 400 ring. `select.form-control` follows this palette; bare scaffold selects,
checkboxes and radios are not canonical public patterns.

### Navigation

Compact chrome with the same access at every width.

The sticky navbar and footer use surface-dark. The wordmark is Title-size Baloo 2.
Desktop primary links use bold Quicksand with 44px minimum height, 6px corners,
8px × 12px padding and amber hover text. The cart remains in the bar on phones;
the hamburger contains primary links, language and account actions. A direct
booking pill is retained in hidden markup, not currently rendered. Dropdowns have
keyboard access, Escape dismissal and focus return, and honour reduced motion.
Locale flags are local SVGs alongside readable language names.

The current category destinations are `/audioprocesses`, `/stories` and `/packages`,
with `/en` for English. Product names and details links lead to the matching
category's slug URL; shop fragments remain separate navigation targets.

Footer headings are uppercase Label in amber. Links keep at least 44px targets and
visible focus outlines; supporting links use tan, and copyright uses readable taupe.

### Joined Offer Pieces (signature)

Two surface-filled links join through a real SVG puzzle seam. Outer corners are
24px; the shared edge is a single hairline. Stacked on phones, side by side from
`md`, with 24px padding rising to 32px from `sm`. Hover or keyboard focus lights the
active piece and shared seam in amber. Decoration is `aria-hidden` and ignores
pointer input. Reduced motion keeps the same emphasis without transitions.

### Reading Disclosure

A short Body summary leads into native `details`/`summary` for longer prose. The
14px amber trigger has a 44px minimum height, a chevron, visible keyboard focus and
localized read-more/read-less labels. Its accessible name includes the section
heading. Expanded content uses `trix-copy`; native disclosure remains usable
without custom JavaScript. The separate FAQ uses the shared button-based accordion
with `aria-expanded` and a labelled content region.

### Audio Product Details

An audioprocess name spans the page above the two-column purchase area; a story
name stays inside its identity column. Identity and purchase information come
before supporting media in DOM order and on phones; from `md`, media sits in the
left column and identity in the right. Fallback artwork uses a video-shaped area
on phones and a square on larger screens. The category and shop back links have
44px minimum targets. Duration appears once below the purchase actions. Program
delivery facts sit below the supporting media; story delivery facts remain with
duration in the purchase column.

Audioprocess details use a reusable suitability/topics variant, followed by the
recording outline. Short topic copy stays visible; longer topics use the native
reading disclosure with product-specific heading and toggle IDs. Stories keep
their simpler description and includes variant. Empty optional sections disappear.
Product names, headings, chapter titles and cart messages wrap at narrow widths
and enlarged text sizes without removing the full owner-written content.

### Package Details Dialog

The overview remains compact while the full benefits and shared prose are retained.
The native modal caps at 800px or viewport width minus 32px, and at viewport height
minus 32px. Header/close and footer/action stay visible while the body scrolls.
Horizontal insets are 20px on phones and 28px from `sm` across all three regions.
Body blocks are separated by 24px; long list items by 12px. The package title names
the dialog, receives initial focus, and Escape restores focus and page scroll.

### Calendar and Recovery

Calendar arrows, day cells and time slots have at least 44px targets. Days are
square; today gets a Field Edge ring, selection is amber with ink text, disallowed
days are muted. Month paging suppresses cell transitions to avoid false fades.
An unavailable schedule replaces the calendar with a readable status and direct
retry/contact actions. Retry performs a fresh GET and preserves the selected
package/date/hour. A successfully read schedule with no slots has a separate state;
do not represent an unavailable service as a fully booked calendar.

### Image Geometry and Viewer

Reserve image geometry before loading. Lightbox thumbnails include intrinsic
width/height and asynchronous decoding; local comparison images use an 800×1100
bounding-box variant without changing their aspect ratio. The comparison remains
the owner's image, in a 640px maximum-width wrapper, with a Body-size enlargement
hint. Do not replace it with a generic table during refinement.

PhotoSwipe JavaScript and CSS load only when an image is opened. Pending opens show
busy/wait state and can be cancelled with Escape; a missing viewer chunk falls
back to the original image link. Viewer controls and errors are localized, and the
custom zoom honours reduced motion. Keep the full original available for zoom.
Portrait and avatar failures use existing mascot or initials fallbacks.

Retained home stats, mascot glow and process-step discs are restoration material,
not active signature components to copy into new screens.

## Do's and Don'ts

### Do:

- **Do** keep public surfaces within the warm palette and use amber for clear emphasis.
- **Do** use the six bundled type levels, with 16px body reading and 14px labels.
- **Do** apply `trix-lead` or `trix-copy` to rich-text containers for the intended role.
- **Do** preserve the fluid section gutters, generous spacing and breakpoint-specific grids.
- **Do** pin overview-card actions to the bottom and let long owner content grow.
- **Do** keep at least 44px targets for phone navigation and calendar interactions.
- **Do** preserve visible amber focus, native semantics and meaningful accessible names.
- **Do** provide readable unavailable states with a concrete recovery action.
- **Do** reserve image geometry and defer heavy viewer code until it is needed.
- **Do** preserve the owner's comparison image and use its original for enlargement.
- **Do** keep fonts and new assets self-hosted, as required by PRODUCT.md's privacy commitment.
- **Do** distinguish documented component defaults from deliberate, existing exceptions.

### Don't:

- **Don't** copy cool-neutral scaffold or `style: :fancy` buttons into public surfaces.
- **Don't** treat retained hidden home sections as the active design.
- **Don't** add a light theme by scattering `dark:` variants into this dark-only system.
- **Don't** shrink explanatory paragraphs to Label size or set them in Baloo 2.
- **Don't** silently change the capitalization or facts in owner-managed content.
- **Don't** add decorative shadows to default in-page cards.
- **Don't** use Taupe Dark for text the visitor needs to read.
- **Don't** shrink calendar targets or hide clipped columns to make a breakpoint fit.
- **Don't** turn a service failure into a misleading empty or fully booked state.
- **Don't** remove native image-link recovery when adding a viewer.
- **Don't** add urgency, scarcity, countdowns or invented review evidence.
