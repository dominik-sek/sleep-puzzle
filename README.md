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

Measured against the design, which is a Claude Design project rather than a file
in this repo — <https://claude.ai/design/p/4578fb79-8a91-4124-8203-4b1f54c72f7d>,
one `Sleep Puzzle Website.dc.html` holding every screen as a
`<main data-screen-label="…">`. It draws 13 screens; only 12 are counted below,
because **Płatność** is deliberately not being built — checkout is Paddle's
overlay, so there is no payment screen of our own. Ticked items are built and
reachable; the rest is what is left.

### Screens

- [x] **Strona główna** — `/` (some sections missing, see below)
- [x] **Pakiety** — `/packages`
- [x] **Kalendarz konsultacji** — `/bookings`, incl. Google Calendar + Paddle
- [x] **Kontakt** — `/contact`, incl. Cloudflare Turnstile
- [x] **O mnie** — `/about`, CMS-driven (`about.*`), incl. the certificates
      collection and the CTA into the calendar
- [x] **Regulamin** — `/terms`, a `<dl>` over the `terms.clauses` CMS collection
      (heading + body, `white-space: pre-line`), linked from the footer and from
      the contact page's tile
- [ ] **Sklep** — `ProductsController` is an empty class and there are no views,
      though `resources :products` is routed and `spec/requests/products_spec.rb`
      is a pending stub. The `Product` model, its admin CRUD and its Paddle price
      already exist, so this is the storefront only: a grid of icon / category /
      name / description / price / "add to cart", plus a product page.
- [ ] **Koszyk** — nothing yet. Needs somewhere to keep a cart (session or table),
      line items with quantity, a total, and remove. Checking out means handing the
      cart to the Paddle overlay the booking flow already drives — there is no
      payment screen of our own to build.

### Newsletter

**Decided: buy, not build.** Brevo holds the list and the campaign editor — the
app already talks to it (`BREVO_API_KEY` is in the environment). That deliberately
keeps consent records, confirmed opt-in, unsubscribe links, bounce handling and
deliverability on Brevo's side rather than ours, and it means there is no
subscriber model, no issue model and no sending code to write here.

What is left on our side is one form:

- [ ] **Sign-up form on the home page.** Drawn in the design (placeholder, button,
      thank-you state) but not built. All it has to do is hand an address to Brevo's
      contacts API and render the thank-you state — the double opt-in mail comes
      from Brevo, so nothing is stored locally. Post it to our own endpoint rather
      than to Brevo from the browser, so the API key stays server-side, and treat
      it like the contact form: it is an unauthenticated public POST, so it wants
      the same rate limiting.

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
- [ ] **Dead links.** Only the two that want the shop are left: navbar "Sklep"
      points at `#` (`NavigationHelper#primary_nav_items`), and the home page's
      "Przejdź do sklepu" renders without an `href`. Neither can be wired yet —
      `resources :products` is routed but `ProductsController` is an empty class
      with no index template, so pointing at it would raise rather than render.
      Both unblock themselves when the Sklep screen lands. Navbar "Blog" is
      commented out rather than pointing at nothing, which is the right shape for
      as long as the blog is parked.
- [ ] **CMS coverage.** `config/content_blocks.yml` declares `home`, `packages`,
      `about`, `terms`, `footer` and `contact`. Each new page above needs its own
      entry so the owner can edit it, followed by `bin/rails content_blocks:sync`.

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
