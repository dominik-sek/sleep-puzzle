# README

## System dependencies

* Ruby 4.0.5 (see `.ruby-version`)
* PostgreSQL
* **libvips** — Active Storage resizes uploaded CMS images through it
  (`ActiveStorage.variant_processor` is `:vips`). Without it an upload succeeds
  but every variant URL 500s with `undefined method 'new' for nil`, because the
  `image_processing` gem is only a wrapper around the C library.

  ```sh
  brew install vips          # macOS
  apt-get install libvips    # Debian/Ubuntu
  ```

  The Dockerfile already installs it, so this is a local-setup step only.

## Editable content (`config/content_blocks.yml`)

Everything the owner can edit on the public site is declared in that one YAML
file and edited at `/admin/content_blocks`. The thing to understand is that
**the YAML is the schema** — no Ruby anywhere names a field. `ContentBlock::Registry`
loads the file into a plain Hash and walks it with three nested `map`s, so meaning
comes from *depth*, not from a list of known names:

| Level | Nested under | Becomes |
| --- | --- | --- |
| 1 | (top level) | a page |
| 2 | `sections:` | a section |
| 3 | `fields:` | a field |

Whatever key sits at level 3 becomes a field whose `key` is that string. Adding
one is therefore just adding lines — there is nothing to register it in.

The key used in a template is flattened back up the chain
(`Section#full_key`, `Field#full_key`), so this:

```yaml
footer:                 # page
  label: Stopka
  sections:
    brand:              # section
      label: Pod logo
      fields:
        tagline:        # field
          label: Opis
          type: plain
          default:
            pl: "Pomagam rodzinom…"
            en: "Helping families…"
```

is read in a view as `content_block("footer.brand.tagline")`.

### Adding a field

1. Add it to the YAML under the right page/section.
2. Run `bin/rails content_blocks:sync` — that is
   `Registry.keys.each { |key| find_or_create_by!(key: key) }`, so it creates a
   blank row per declared key and never touches copy anyone has already written.
3. Read it in the template with `content_block("page.section.field")`
   (`content_image` for `image` fields, `content_items` for a collection).

### Rules worth knowing

* **Types** are `plain`, `rich` (Action Text, with a Trix editor) or `image`
  (one upload, not one per language). An unknown type raises at boot, naming the
  exact `page.section.field`.
* **`label:` is required** at every level — a missing one raises `KeyError` on
  load rather than rendering an unlabelled box in the panel.
* **`default:` is optional.** It is the copy the page ships with, used whenever
  the database has nothing — including on a fresh deploy — so no section ever
  renders blank. `en` may be omitted and falls back to `pl`.
* **`fields:` is optional too**, which is what lets a section hold only a
  `collection:` (see `home.stats`) — a repeating list the owner can add to and
  remove from, whose items carry short `plain` strings only.
* **Order follows the file.** Ruby hashes keep insertion order, so the sequence
  in the YAML is the sequence in the admin panel; moving a field means moving
  its lines.
* **The registry reloads per request in development** and is memoised elsewhere,
  so editing the YAML locally needs a page refresh, not a restart.
* **An unknown key** passed to `content_block` raises in development and test and
  is ignored in production — a typo should be loud while building a page and must
  never take a live page down.

## Roadmap

Measured against the design (`Sleep Puzzle Website.dc.html`, 12 screens). Ticked
items are built and reachable; the rest is what is left.

### Screens

- [x] **Strona główna** — `/` (some sections missing, see below)
- [x] **Pakiety** — `/packages`
- [x] **Kalendarz konsultacji** — `/bookings`, incl. Google Calendar + Paddle
- [x] **Kontakt** — `/contact`, incl. Cloudflare Turnstile
- [ ] **O mnie** — no route, controller or view. Navbar links to `#`. Design wants
      photo, name + role, three paragraphs with a pull-quote, a certificates list
      and a CTA into the calendar. All copy belongs in the CMS.
- [ ] **Sklep** — `ProductsController` is an empty class and there are no views,
      though `resources :products` is routed and `spec/requests/products_spec.rb`
      is a pending stub. The `Product` model, its admin CRUD and its Paddle price
      already exist, so this is the storefront only: a grid of icon / category /
      name / description / price / "add to cart", plus a product page.
- [ ] **Koszyk** — nothing yet. Needs somewhere to keep a cart (session or table),
      line items with quantity, a total, and remove. Checking out means handing the
      cart to the Paddle overlay the booking flow already drives — there is no
      payment screen of our own to build.
- [ ] **Regulamin** — nothing yet. It is a flat list of heading + body sections,
      which fits a CMS collection rather than a model.

### Newsletter

**Open decision: build or buy.** Everything below assumes we build it. The
alternative is to let Brevo hold the list and the campaign editor, and for the
site to do nothing but hand it an address — which removes the second bullet
entirely, along with owning consent records, unsubscribe links, bounce handling
and deliverability. Worth settling before any of this is picked up.

If we build it, nothing exists yet — no model, no form, no sending. Two halves:

- [ ] **Collecting subscribers.** The sign-up form on the home page is drawn in the
      design (placeholder, button, thank-you state) but not built. Needs a
      subscriber record, and — since the audience is in the EU — an explicit consent
      checkbox, confirmed opt-in, and a working unsubscribe link on every send.
- [ ] **Writing and sending an issue.** The owner has to be able to compose what
      goes out, not just trigger a fixed template. That is a different shape from
      `content_blocks.yml`, which edits fixed keys on a page: an issue is a record
      the owner creates, with a subject and a rich-text body, kept as a draft until
      they send it. Reuse the Action Text editor the CMS rich fields already use,
      and send through a background job in batches rather than one mail per
      request.
- [ ] Decide whether sending goes through the existing SMTP setup or a dedicated
      provider. The app already talks to Brevo (`BREVO_API_KEY` is in the
      environment), so that is the obvious first place to look.

### Missing sections on the home page

- [ ] Kicker badge above the hero headline
- [ ] Media / podcast strip
- [ ] Newsletter sign-up form (see Newsletter, above)

### Cross-cutting

- [ ] **PL/EN switcher.** The design has a language toggle in both the desktop and
      mobile nav. The plumbing is already here — `Translatable`, `en` defaults
      throughout `config/content_blocks.yml`, `config/locales/en.yml` — but nothing
      ever assigns `I18n.locale`, so every English translation in the database is
      currently unreachable.
- [ ] **Dead links.** Navbar "O mnie" and "Sklep" point at `#`; the footer's list
      items are plain text rather than links (only "Kontakt" is wired); and on the
      home page "Zobacz pakiety" and "Przejdź do sklepu" render without an `href`.
      Most of these unblock themselves as the pages above land. Navbar "Blog" stays
      dead for as long as the blog is parked — worth hiding rather than leaving it
      pointing at nothing.
- [ ] **CMS coverage.** `config/content_blocks.yml` declares `home`, `packages` and
      `contact`. Each new page above needs its own entry so the owner can edit it,
      followed by `bin/rails content_blocks:sync`.

### Placeholder, not finished

- [ ] **Moje konto** — `/dashboard` renders hardcoded stand-in markup ("Nazwa play",
      "Form with account settings will be here"), and `DashboardController` still
      has `@audiobooks` and `@bookings` commented out. The design wants a purchased
      audio library, the upcoming booking, and account settings — each with an
      empty state.

### Parked

- **Blog** and **Wpis na blogu** — designed (list and post screens) but deliberately
  not being built for now. Nothing in the app depends on them.

## Everything else

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
