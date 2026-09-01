# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

**Primary: an exhausted parent of a young child, mid-crisis.** They are in a bad
stretch - sleep-deprived, reading on a phone, often at night, often one-handed in a
dark room with a child asleep nearby. Reading capacity is low, patience is lower,
and the decision is made emotionally before it is justified rationally. They arrive
needing relief, not a comparison table.

Two things follow and are binding on every surface: **the phone at 3am is the real
usage scene, not the desktop**, and **the first screen has to earn trust before it
asks for anything**.

**Secondary: the owner (Karola)**, who runs the site herself through
`/admin/content_blocks` and the admin panel. She is not a developer. Anything she
might reword must be a content block, not a hardcoded string - the staff-facing
panel and the calendar screen are deliberately Polish-only.

## Product Purpose

Sleep Puzzle sells Karola's help to families whose sleep has fallen apart, in two
forms:

* **Consultation packages** - 1:1 work, booked against her real calendar, paid
  before the slot is held.
* **Audio** - "audioprocesy" for parents working on sleep on their own, and
  soothing audio stories for children.

Success is a parent who books or buys on the first visit, and an owner who can
change any word on the public site without asking anyone.

## Positioning

**People buy Karola, and they buy access to her.** The differentiator is the person
and the ongoing availability during a package - the voice, the humour, "a talking
encyclopedia in your pocket" - not a proprietary method or a schedule template. A
neighbouring consultant can copy a package structure; they cannot copy her.

The stated belief underneath it: healthy sleep starts with empathy, support and an
emotionally cared-for *adult*, and every family is a different puzzle with a
different pace. Nothing is one-size-fits-all.

The audio catalogue and the consultations form one ladder - self-serve for families
who can't reach 1:1, 1:1 when they can - rather than a single price point.

## Operating Context

* **Arrival is mobile and social-led.** The visitor is likely coming from Instagram
  on a phone, at the end of a bad night.
* **Two languages, one canonical address per page.** Polish is the bare path;
  English is the same page under `/en`. A block with no English version falls back
  to Polish on purpose - that is content awaiting translation, not a defect.
* **Booking runs against a real calendar.** A visitor picks a slot, fills a short
  form, and pays through Paddle's overlay; the confirmed booking writes into the
  owner's Google Calendar (in Polish, regardless of the buyer's language).
* **The owner edits copy live.** `config/content_blocks.yml` is the schema: pages →
  sections → fields, typed `plain`, `rich` (Trix) or `image`. Every declared field
  ships with a default, so no section can render blank. **A new public surface that
  does not add its own entry is not editable** - and unrewordable chrome (navbar,
  footer headings, language switcher) belongs in `nav.*` in the locale files
  instead.
* **The staff side is separate.** Admin panel, Solid Queue dashboard and PgHero all
  live under `/admin`, gated by one `users.admin` boolean.

## Capabilities and Constraints

* **No price is stored in this application.** A `Product` or `Package` holds a
  `paddle_price_id`, and every figure on screen is read back from Paddle. A product
  whose price cannot be read renders with no add button - so any surface showing
  money must have a truthful "price unavailable" state.
* **Paddle is Merchant of Record.** Checkout is Paddle's overlay; there is no
  payment screen of our own, and closing the overlay is reported back by the browser
  so the lines return to the cart.
* **Everything sold is a file or a slot - there are no quantities.** A cart line is
  only ever added or removed, and anything the buyer already owns is kept out of the
  cart, the order and the total.
* **A product cannot be published without its audio file.** The validation refuses
  it and the published scope excludes it, so the shop never offers something there
  is nothing to deliver for. Products still missing a file are drafts, not listings.
* **Audio is streamed, never handed over.** Files sit on a token-authenticated Bunny
  pull zone; `/products/:id/stream` checks ownership and redirects to a URL signed
  for six hours. Uploads are proxied by the app so the write key never reaches a
  browser.
* **Accounts** are Devise plus Google OAuth. A Google sign-up has **no password**,
  so no account surface may assume one exists.
* **Deliberately absent, decided against, not to be re-proposed:** a buyer-facing
  purchase history (Paddle emails the receipt; the dashboard library answers the
  question buyers actually ask); a subscriber model (Brevo owns the list, the double
  opt-in and the unsubscribe); an English admin panel; the hero kicker badge; the
  blog teaser.
* **Open / not yet built:** a media-and-podcast strip on the home page.

## Brand Commitments

* **Name:** Sleep Puzzle. The puzzle is the governing metaphor and it is literal in
  the copy - "układa sen rodzin jak puzzle", piece by piece, every family a different
  układanka.
* **Voice:** first person, warm, direct, unpolished on purpose, and funny. She calls
  herself "baba z internetów". The site's own quote is *"Piasek jest fajny - na
  plaży. Nie pod powiekami" :)* - smileys and all. No corporate register, no
  pressure, no fear-selling to people who are already frightened.
* **Assets in repo:** logo lockups (black / white / dark), a mascot in six
  colourways, and an avatar, under `app/assets/images`.
* **Typefaces are self-hosted and load-bearing to the privacy stance:** Quicksand
  (body) and Baloo 2 (display), both SIL OFL, subset latin / latin-ext because the
  Polish site needs ą/ć/ę/ł/ń/ś/ź/ż.
* **Privacy is a product commitment, not a setting.** A visitor who only reads the
  site makes **no third-party request at all**; the only cookie is our own session,
  so there is no consent banner. No analytics, no tag manager, no ad pixel, no font
  CDN. Paddle.js loads only when a checkout opens. **Adding any third-party asset,
  script, embed or hosted font breaks this and requires an explicit decision** - the
  one existing exception is a hotlinked Google avatar for users who signed in with
  Google.

## Evidence on Hand

Real and usable - do not embellish, do not invent more:

* **Credentials:** OCN Level 6 Sleep Consultant certification (mentored, externally
  assessed exams); Child Care Development qualifications at degree level; Certified
  CBTi Insomnia Therapist.
* **Experience:** over 20 years supporting children and parents. The home page
  carries a `stats` collection whose only shipped entry is "20+ lat".
* **Owner photo and avatar** exist as content-block image fields and repo assets.

Absent, and **not to be fabricated**: testimonials, named clients, case studies,
press mentions, review scores, success rates, outcome statistics, subscriber or
customer counts, and any pricing figure not read back from Paddle.

## Product Principles

1. **Design for 3am on a phone.** The exhausted first visit is the design target;
   the calm desktop read is the exception. Low reading load, large touch targets,
   nothing that punishes a mis-tap.
2. **Warmth is the product, not the decoration.** The voice is the differentiator -
   surfaces that sand it into corporate neutrality destroy the thing being sold.
3. **Never trade on fear.** The visitor is already frightened and guilty. No
   urgency mechanics, no scarcity counters, no implied failure as a parent.
4. **The owner must be able to change any public word herself.** A new surface ships
   with its content-block entries or it is incomplete.
5. **Privacy holds by default.** No surface introduces a third-party request. The
   absence of a cookie banner is a feature that must keep being earned.
6. **Never show money or a buy action the system cannot honour.** Prices come from
   Paddle and files must exist; every commerce surface owns its unavailable state.

## Accessibility & Inclusion

**WCAG 2.1 AA is binding**, as the European Accessibility Act applies to this EU
e-commerce site. Beyond the standard, the primary user's real conditions -
one-handed phone use, a dark room, severe sleep deprivation - mean contrast,
target size, focus visibility and error recovery are correctness requirements here,
not polish.

## Open Decisions

* **The English audience is aspirational for now.** Polish is the business. The `/en`
  routes and the Polish fallback exist so it can be switched on later; partial
  translation is acceptable and English surfaces do not owe equal design effort until
  an audience is confirmed. Do not write positioning or content that presumes an
  English market exists.
