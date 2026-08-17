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

## Shop, cart and checkout

Three pieces, and the thing to understand is that **no amount is ever stored
here**. Paddle owns the money (see `Purchasable`): a `Product` carries a
`paddle_price_id` and nothing else about price, and every figure on screen is
read back through `PaddlePriceCatalogService`. That is why a product whose price
cannot be read renders as "Chwilowo niedostępne" with no add button, and why
`Cart#total_label` returns `nil` rather than a total that quietly omits a line —
it is the number the buyer checks before paying.

Each product carries its **own emoji** in `products.icon`, set in the admin
panel, because the design gives every card and cart line a distinct one (🌙, ☀️,
🧸) rather than one per kind. It is nullable — `Product#display_icon` falls back
through `Product::KIND_ICONS` — so a product added without one still renders.

The design has no product detail screen: clicking a card's name in it goes
nowhere. `/products/:id` is ours, so a product has a shareable URL and somewhere
to show the full description the card clamps to three lines.

### The cart is the session

`Cart` is not an `ActiveRecord`. It wraps `session["cart"]`, which holds nothing
but `{ product_id => quantity }`:

* **Nothing to expire.** A table would mean a row per anonymous visitor and a
  sweep job to clean them up, for a list the buyer can rebuild in three clicks.
* **Nothing to merge.** The session survives sign-in, so a cart filled while
  signed out is still there afterwards — which is what lets checkout ask for an
  account only at the very end.
* **Products are resolved on read**, through `Product.published`. Something
  unpublished or deleted after it was added simply drops out of the cart, with
  nothing having to reach into everyone's session.

Quantities are clamped to `Cart::MAX_QUANTITY`, which is a guard and not a
business rule: the session is a cookie, and an unbounded cart would let one
visitor fill it past the 4KB limit and break every later write.

### Checkout is the Paddle overlay

The design draws a payment screen with card fields. It is deliberately not built —
Paddle's overlay collects the card, so the only thing on our side is turning the
cart into something Paddle's webhook can name:

1. `OrdersController#create` builds a **pending** `Order` from the cart and empties
   the cart, because the order now holds what the cart held.
2. `shared/_paddle_checkout` mounts the Stimulus controller, which opens the
   overlay with every line and `customData: { order_id }`.
3. Paddle redirects to `orders#show`, which says "still confirming" until the
   webhook lands rather than claiming success on its own.
4. `paddle_billing.transaction.completed` reaches `OrderConfirmationService`,
   which flips the order to `paid`.

`orders#abandon` is what happens when the buyer closes the overlay: **closing it
fires no webhook**, so the browser reports it instead. The order is deleted and
its lines go back into the cart, so a mis-click does not cost the buyer their
basket.

### Two subscribers on one event

Bookings and orders both check out through Paddle, so both subscribe to
`paddle_billing.transaction.completed`. Each ignores what is not its own: a
booking checkout puts `booking_id` in `customData`, an order puts `order_id`, and
`PaddleTransactionService` returns `nil` for the other one and logs why.

That base class also holds the check worth knowing about — **`customData` is set
in the browser**, so a tampered checkout could name someone else's record. Before
anything is acted on, the Paddle customer that was actually charged is matched
back to the record's owner. Both services are idempotent, because Pay re-runs the
whole chain when its own charge sync raises.

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
- [x] **Sklep** — `/products`, a grid of category / name / description / price /
      "do koszyka" plus a product page. Prices are read back from Paddle, so a
      product whose price cannot be read renders without an add button
- [x] **Koszyk** — `/cart`, session-backed, with quantities, a total and remove.
      Checkout hands the cart to the Paddle overlay (see *Shop, cart and checkout*
      below)

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
- [x] **Dead links.** All wired. Navbar "Blog" stays commented out rather than
      pointing at nothing, which is the right shape for as long as the blog is
      parked.
- [ ] **CMS coverage.** `config/content_blocks.yml` declares `home`, `packages`,
      `about`, `shop`, `cart`, `terms`, `footer` and `contact`. Each new page above
      needs its own entry so the owner can edit it, followed by
      `bin/rails content_blocks:sync`.

### Placeholder, not finished

- [ ] **Moje konto** — `/dashboard` renders hardcoded stand-in markup ("Nazwa play",
      "Form with account settings will be here"), and `DashboardController` still
      has `@audiobooks` and `@bookings` commented out. The design wants a purchased
      audio library, the upcoming booking, and account settings — each with an
      empty state. The library half now has something to read:
      `current_user.purchased_products` returns the deduplicated products from
      that user's paid orders.
- [ ] **Delivering what was bought.** An order records *what* was paid for, but
      nothing yet attaches an audio file to a `Product` or streams it to the
      buyer — "Moje audio" has a list and no player. Wants an Active Storage
      attachment on `Product` and a controller that authorises against
      `purchased_products` before sending the file.

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
