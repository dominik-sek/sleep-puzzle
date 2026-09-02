# Sleep Puzzle
Live version: [sleeppuzzle.com](https://sleeppuzzle.com)

**Rails 8 storefront for a children's-sleep consultant.**

> It sells audio programmes and paid consultations, allows booking consultations through Google Calendar,
delivers the files from a signed CDN, lets the owner edit the site's content
without a redeploy.

## What it does

1. **Sells two things at once** - audiobooks delivered instantly with an option to preview the first 30 seconds of them, and consultation slots, which are fetched real time through Google Calendar.


2. **Takes payment through Paddle** as Merchant of Record, so VAT, invoicing and
  receipts are handled externally as opposed to **Stripe**


3. **Books against live availability** - free slots are computed from the owner's
  actual Google Calendar, fetching events from the API in order to block out
  unavailable times (not only bookings but also time off, holidays, etc.).


4. **Is edited by its owner.** Every heading, paragraph, stat and image on the public
  site is a content block the owner can change in both languages.


5. **Is bilingual** - Polish on the bare path, English under `/en`, down to the
  emails and the error pages.

## Stack

### App
- Rails 8.1
- Hotwire (Turbo + Stimulus) 
- ViewComponent
- [RailsBlocks](https://railsblocks.com/)
- Tailwind 4 through Vite
- Devise + Google OAuth
- RSpec
- Google Calendar API
- Cloudflare Turnstile
- Brevo
### AI
- Claude Code
- [Impeccable Style](https://impeccable.style/)
### Storage
- PostgreSQL, with Solid Queue / Cache / Cable in the same database
- Bunny CDN
### Payments
- Paddle 
### Deployment
- Cloudflare for TLS and redirects
- Kamal on a single VPS

### The CMS schema is a YAML file

The owner is not a developer, and anything that can be reworded has to be editable
without a deploy.

`config/content_blocks.yml` **is the schema**: no Ruby names any field, and meaning comes from nesting depth (page ->
section → field).

Adding an editable paragraph is four lines of YAML and `content_block("footer.brand.tagline")` in the view.

## Running it locally

```sh
cp .env.example .env    # every variable is documented in there
bin/setup
bin/dev
```

Needs Ruby 4.0.5, PostgreSQL, libvips and ffmpeg.

## Docs

| | |
| --- | --- |
| [docs/content-blocks.md](docs/content-blocks.md) | The content-block schema in full |
| [PRODUCT.md](PRODUCT.md) | Who this is for and what it's meant to do |
| [DESIGN.md](DESIGN.md) | The design system it's built to |
