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

`/products/:id` follows the design's **Produkt** screen: a large icon panel beside
the buy column, a spec strip (długość / format / dostęp), then "O tym nagraniu"
and "Co dostajesz", then up to three other products. Three of those fields are the
product's own — `length_minutes` (an integer, formatted through
`t("products.length_minutes")`, because a number reads the same in both languages)
plus the translated `long_description` and the `includes` bullet list. Format and
access are the same sentence for everything sold, so they are CMS copy rather than
columns. Every section below the buy column is skipped when the owner has not
filled it in, so a product added in a hurry renders as just the top half rather
than as a page of empty headings.

### The cart is the session

`Cart` is not an `ActiveRecord`. It wraps `session["cart"]`, which holds nothing
but a **set of product ids**:

* **Nothing to expire.** A table would mean a row per anonymous visitor and a
  sweep job to clean them up, for a list the buyer can rebuild in three clicks.
* **Nothing to merge.** The session survives sign-in, so a cart filled while
  signed out is still there afterwards — which is what lets checkout ask for an
  account only at the very end.
* **Products are resolved on read**, through `Product.published`. Something
  unpublished or deleted after it was added simply drops out of the cart, with
  nothing having to reach into everyone's session.

**There are no quantities.** Everything sold is a digital file — an MP3, an MP4 —
so a second copy of one is the same copy. That single decision is why `Cart#add`
is idempotent, why `OrderItem` is nothing but the join between an order and a
product, and why the shop's button is a *toggle*: press it once to add, again to
remove, rather than counting up. `Order#paddle_items` always sends
`quantity: 1`, because Paddle wants the key.

**Nothing is ever sold twice.** A file already bought is not something to sell
again, so ownership blocks it at three levels rather than one: the shop's button
becomes a link into the account, `CartItemsController` refuses the POST behind it,
and `Cart` keeps owned products out of `#lines` altogether — which is what covers
the case nothing else would, a cart filled *before* signing in that turns out to
hold something this account already owns. Because `count`, `total_label` and the
order all read through `#lines`, an owned file cannot be counted, totalled or
charged. It is reported separately as `#already_owned` so the cart can say where
it went instead of appearing to have lost it.

The cart is capped at `Cart::MAX_ITEMS`, which is a guard and not a business
rule: the session is a cookie, and an unbounded cart would let one visitor fill
it past the 4KB limit and break every later write.

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

One thing Paddle enforces that is easy to trip over: a price can carry a **maximum
quantity**, and a checkout that asks for more than it allows is rejected outright.
Nothing here ever sends more than 1 (see *There are no quantities* above), so this
only matters if quantities are ever reintroduced.

### Looking a purchase up afterwards

`/admin/orders` is where "I paid and cannot see my audio" gets answered: the buyer,
what they bought, and the **Paddle transaction id**, which is what a refund or a
dispute is looked up by on Paddle's side. An order sitting on *oczekuje* with no
transaction id is itself the diagnosis — the `transaction.completed` webhook never
landed.

There is deliberately **no buyer-facing purchase history**. Paddle is Merchant of
Record, so it is the seller on the transaction and emails the buyer their receipt
and invoice; the obligation is Paddle's, not ours. What a buyer actually asks is
"where is the thing I bought", and the dashboard library answers that. Everything
a history screen would need — `paid_at`, `paddle_transaction_id`, the items — is
already recorded, so it stays a view away rather than a migration away. That
changes if Paddle ever stops being Merchant of Record, at which point invoicing
becomes ours.

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

## Two languages, two addresses

Polish keeps the bare paths it always had; English is the same page under `/en`:

```
PL   /            /packages     /about     /products/12
EN   /en          /en/packages  /en/about  /en/products/12
```

The locale lives in the **path**, not the session, so each language has its own
indexable, shareable address and the `<link rel="alternate" hreflang>` tags in the
layout can tell Google they are the same page twice. A session would have left
every English translation invisible to search and made a shared link open in
whatever language the reader last chose.

Three things are worth knowing before touching this.

**Only the public routes are scoped.** Devise, the admin panel and the OAuth
callbacks sit outside `scope "(:locale)"`, because their URLs are registered with
Google and with Paddle and cannot move. The language still follows you onto them,
as `?locale=en` — which is what keeps someone who switched to English in English
when they sign in.

**The constraint is `/en/`, not `/pl|en/`.** Only the non-default locale ever
appears, so there is one canonical address per page; `/pl/about` is a 404 rather
than a duplicate of `/about`.

**`Rails.application.routes.default_url_options[:locale] = nil` is load-bearing.**
An optional *leading* dynamic segment swallows the first positional argument, so
without that line `product_path(product)` binds the product to `:locale` and
raises `missing required keys: [:id]`. Declaring the key — as nil, so Polish paths
stay unprefixed — makes positional arguments land where they were written to. It
is set at the routes level rather than only in `ApplicationController` because
mailers and jobs generate URLs with no controller and hit the same bug.

The switch itself is `around_action :switch_locale`, using `I18n.with_locale`
rather than assigning `I18n.locale`: it is a thread-global, and a request that set
it and then raised would leave the next request on that thread rendering in the
wrong language.

## Roadmap

Measured against the design, which is a Claude Design project rather than a file
in this repo — <https://claude.ai/design/p/4578fb79-8a91-4124-8203-4b1f54c72f7d>,
one `Sleep Puzzle Website.dc.html` holding every screen as a
`<main data-screen-label="…">`. It draws 14 screens; only 13 are counted below,
because **Płatność** is deliberately not being built — checkout is Paddle's
overlay, so there is no payment screen of our own. The design is edited while this
is being built, so re-pull it rather than working from an older copy. Ticked items
are built and reachable; the rest is what is left.

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
      "do koszyka". Prices are read back from Paddle, so a product whose price
      cannot be read renders without an add button
- [x] **Produkt** — `/products/:id`, incl. the spec strip, "O tym nagraniu",
      "Co dostajesz" and the "Inne materiały" tiles
- [x] **Koszyk** — `/cart`, session-backed, with a total and remove (no
      quantities — see above).
      Checkout hands the cart to the Paddle overlay (see *Shop, cart and checkout*
      below)
- [x] **Moje konto** — `/dashboard`, incl. the paid-orders library, upcoming
      consultations and the link into Devise's account form, each with its empty
      state. The library has no player yet — see *Placeholder, not finished*

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

- [ ] **Paddle errors are still invisible.** The layout re-emits every Paddle event,
      but `paddle_controller.js` switches on `checkout.completed` and
      `checkout.closed` only — `checkout.error` falls through, so Paddle's own
      message never reaches the console or a toast. That is why the max-quantity
      rejection had to be diagnosed by hand. Small, and it makes the next one
      self-explaining.

- [x] **PL/EN switcher.** In the path — see *Two languages, two addresses* above.
- [x] **Dead links.** All wired. Navbar "Blog" stays commented out rather than
      pointing at nothing, which is the right shape for as long as the blog is
      parked.
- [x] **CMS coverage.** Every page that exists is editable: `content_blocks.yml`
      declares `home`, `packages`, `about`, `shop`, `cart`, `dashboard`, `terms`,
      `footer` and `contact`. This stays true only if each new page adds its own
      entry, followed by `bin/rails content_blocks:sync`.

### Placeholder, not finished

- [ ] **Delivering what was bought.** This is the one thing standing between a
      paid order and a customer with their file. `/dashboard` lists the library,
      but **there is no player and no download**, because nothing hosts the audio
      yet — a play button with no file behind it would be a lie, so the rows are
      links to the product rather than a fake control. The files are going on a
      CDN; what this app then needs is somewhere to keep the URL per `Product`
      and a check that the person asking is in `purchased_products` before handing
      it over. Whether that check is ours or a signed CDN URL is the decision to
      make when the CDN is picked.

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
