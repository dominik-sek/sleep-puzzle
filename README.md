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

## Signing in

The five Devise screens — sign in, sign up, account details, forgotten password,
set new password — were generator scaffolding: English, unstyled, and each one a
copy of the same wrapper. They now share `devise/shared/_card` and
`devise/shared/_field`, which is what stops one of them being restyled and the
other four being forgotten again.

Copy lives under `auth.*` in `pl.yml` and `en.yml`, deliberately outside the
`devise.*` scope the gem owns, so there is no chance of colliding with it on a
gem upgrade. Devise's own flashes and failures come from `config/locales/devise.pl.yml` —
the gem ships English only, so without that file every message in the sign-in
flow arrived in English on a Polish site.

Two pieces of wiring were wrong and are worth knowing about:

* **`config.parent_mailer = "ApplicationMailer"`.** Without it Devise's mailer
  descends from `ActionMailer::Base`, which means no layout and none of the
  `from`/`reply_to` defaults every other mail in this app gets — the reset mail
  went out as a bare unstyled fragment.
* **`config.mailer_sender` was the generator's `please-change-me@example.com`**,
  which is not a deliverable address; a reset mail from it is rejected or filed as
  spam. It now reads `MAIL_FROM`, and it is written `->(*)` because Devise calls it
  with the devise mapping — a zero-arity lambda raises `ArgumentError` on the first
  send.

**A Google sign-up has no password, deliberately.** It used to be given
`Devise.friendly_token` — a random string the holder was never told. That let them
in through Google and nowhere else, but it also made `encrypted_password` look set,
so `/users/edit` demanded a "current password" they could not possibly know and
refused every change they tried to make, including setting a real password.

Now nothing is stored, `User#password_set?` answers the question honestly, and
`Users::RegistrationsController` drops `:current_password` for an account that has
none. Three details matter if this is ever touched:

* `User#password_required?` excuses **only** the create-with-no-password case.
  Returning true whenever no password was submitted would demand one on every
  update, which is exactly how an email-only change breaks for everyone else.
* The override drops `:current_password` rather than calling Devise's
  `update_without_password`, because that strips `:password` too — leaving a Google
  user unable to set the first password they came to set.
* The exemption ends the moment a password exists. Once set, confirming it is
  required again, the same as any other account.

Google sign-in uses Google's own multicolour mark and stays on a white button,
because Google's brand guidelines expect it on white or on its own blue rather
than tinted to a host palette. `data-turbo: false` on it is required rather than
cosmetic: the handshake is a full-page redirect off-site, and Turbo would try to
fetch it and fail.

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

**On the public site the URL is the whole answer.** A scoped route states the
language in its path, so a path without one means Polish — however long ago
someone clicked EN. That is what keeps one address per rendering, and it is what
lets the switcher get *back*: its Polish link is the bare path, and if a remembered
choice could override that there would be no way home.

**The choice is remembered only for routes that cannot state it.** Devise, the
panel, and above all the Google handshake — which leaves for accounts.google.com
and returns to `/users/auth/google_oauth2/callback` with nothing to say which
language was picked, so the sign-in redirect it builds would land on the Polish
dashboard. `session[:locale]` is written on every public page and read only where
the path has no locale to offer. Which of the two a request is gets read off
`request.route_uri_pattern` — `"(/:locale)/about(.:format)"` versus
`"/users/sign_in(.:format)"`.

Do **not** answer that question by generating a URL and looking at it.
`ActionController` memoises `url_options` on first use, so calling `url_for` before
`with_locale` has run freezes `locale: nil` into every link the page then
generates — the page comes out in English with Polish links, which is a confusing
thing to debug.

**Two places Polish hides that a view-by-view pass will not find.** Both bit this
codebase and both are now covered by `spec/requests/english_pages_spec.rb`, which
scans a rendered English page for Polish diacritics rather than checking for a
handful of phrases someone thought of:

* **Frozen label Hashes on models.** `Booking::PAYMENT_STATUS_LABELS`,
  `Product::KIND_LABELS` and `Order::STATUS_LABELS` were Polish strings in Ruby, so
  "Audioproces" appeared on the English shop no matter how well the template was
  translated. They are `I18n.t` lookups behind `#status_label` / `#kind_label` now.
  One deliberate exception: `BookingCalendarService` asks for Polish explicitly,
  because that string goes into the *owner's* calendar and an English buyer's
  booking should not retitle her day.
* **JavaScript.** `cally_controller.js` called `dayjs.locale("pl")` at import, so
  every month and weekday name in the date picker was Polish whatever the page
  around it said.

  Fixing that by reading `document.documentElement.lang` at import was still wrong,
  in two ways worth remembering. A controller module is evaluated **once per full
  page load**, so anything decided at import survives every Turbo navigation
  afterwards — the picker stayed in whatever language you arrived in until you
  pressed reload. And `<html lang>` is itself stale after a navigation, because
  Turbo Drive swaps the `<body>` and merges the `<head>` but never touches the
  attributes on `<html>`.

  So the locale is rendered by the server onto the element
  (`data-cally-locale-value`) and read in `connect()`, which runs again on every
  navigation. `locale_controller.js` separately copies the language from the body
  back up to `<html lang>`, so screen readers and anything else reading it get the
  truth.

Unscoped routes still pick up `?locale=en` from `default_url_options`, since it
cannot know whether the target takes the locale as a path segment or a query
string. It is redundant now that the session remembers, and harmless — it also
makes such a link portable.

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

- [x] **Navbar, footer and the home page's CTAs** now read from `nav.*` in
      `pl.yml`/`en.yml` rather than being hardcoded Polish. Copy the owner writes
      still lives in the CMS, and a block with no English version falls back to
      Polish on purpose — that is content waiting to be translated, not a bug.
- [ ] **The admin panel and the Google Calendar integration screen are
      Polish-only.** `integrations/google_calendar/show` still holds literals, and
      nothing under `admin/` has been translated. Both are staff-facing, so this
      only matters if a non-Polish speaker ever runs the panel.
- [ ] **Two Devise screens are still stock English** — `confirmations/new` and
      `unlocks/new`, plus the `confirmation_instructions` and `unlock_instructions`
      mails. Both modules are switched off in `User`, so nothing reaches them; they
      only matter if `:confirmable` or `:lockable` is ever enabled.

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
