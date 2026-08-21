# README

## System dependencies

* Ruby 4.0.5 (see `.ruby-version`)
* PostgreSQL
* **libvips** — Active Storage resizes uploaded CMS images through it
  (`ActiveStorage.variant_processor` is `:vips`). Without it an upload succeeds
  but every variant URL 500s with `undefined method 'new' for nil`, because the
  `image_processing` gem is only a wrapper around the C library.

  Two pieces are needed, and they fail differently. The `ruby-vips` gem is the
  Ruby binding, and it is an explicit entry in the Gemfile: `image_processing`
  2.0 dropped it as a dependency and made its backends opt-in, so without that
  line the app does not boot at all — Active Storage's initializer requires
  `image_processing/vips` and raises `LoadError`. The libvips C library below is
  the thing the binding binds to, and its absence is the 500 described above.

  ```sh
  brew install vips          # macOS
  apt-get install libvips    # Debian/Ubuntu
  ```

  The Dockerfile already installs it, so this is a local-setup step only.

## Database configuration

`config/database.yml` holds no credentials. Host, port, username and password
all come from the environment — `.env` locally (dotenv-rails is in the
`development, test` group, so it loads for every boot path), real env vars in
production:

| Variable | Default | Notes |
| --- | --- | --- |
| `DATABASE_HOST` | `localhost` | |
| `DATABASE_PORT` | `5432` | |
| `DATABASE_USERNAME` | blank | Blank means peer auth as the OS user |
| `DATABASE_PASSWORD` | blank | |
| `DATABASE_NAME` | `sleep_puzzle_development` / `sleep_puzzle_production` | One database per environment; the solid_* tables live in it too |
| `TEST_DATABASE_NAME` | `sleep_puzzle_test` | Separate key so dev and test never collide when `DATABASE_NAME` is set |

Only the database names have defaults, and those are not secrets. `DATABASE_URL`
still wins over everything above — Rails merges it on top of the file — which is
how CI points the suite at its own postgres service without touching this file.

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

### Paddle.js loads only at checkout

`cdn.paddle.com/paddle/v2/paddle.js` used to sit in the application layout, so it
ran on every page — including the home page, for a visitor who was never going to
buy anything. Paddle sets cookies when it initialises, and none of them are
exempt from the ePrivacy "strictly necessary" carve-out at that point: the visitor
has not asked for anything a payment processor is needed for. That is a cookie
banner's worth of obligation for a script almost nobody on the page will use.

So `app/frontend/lib/paddle.js` fetches it instead, the first time a checkout
actually opens. By then the buyer has clicked through to a pending order or
booking and asked for the overlay, which is what makes the storage necessary to a
service they requested — no consent gate needed. The load is memoised on the
promise, so a second checkout in the same visit waits on the first fetch rather
than racing it, and a failure clears the memo so a retry starts over.

Two consequences worth knowing:

- **The token and environment come from the checkout partial now**, not the
  layout. `shared/_paddle_checkout` passes `Pay::PaddleBilling.client_token` and
  `Pay::PaddleBilling.environment` as Stimulus values. The environment used to be
  hardcoded to `"sandbox"` in the layout; it now follows
  `PADDLE_BILLING_ENVIRONMENT`, which is what production needs.
- **Opening the overlay is asynchronous.** `paddle_controller` awaits the script
  before calling `Checkout.open`, and a blocked CDN now surfaces as a rejected
  load rather than a missing global. The blocked-script toast and the automatic
  abandon behave as before; there is also a 10s timeout, because a blocker that
  answers with an empty 200 fires neither `load` usefully nor `error`.

The remaining third-party request on a cold page is Google Fonts, which sets no
cookies but does hand Google every visitor's IP. Self-hosting it is still open.

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

### Delivering the audio

The recordings live on a **Bunny** storage zone, behind a pull zone with **Token
Authentication** switched on. That matters: a pull zone is public by default, so
without token auth anyone who guessed a filename would have the file. With it,
the zone refuses every request that does not carry a valid signature, and minting
signatures is the only thing this app has to guard.

Each `Product` stores a `cdn_path` — the path inside the storage zone,
`/bajki/o-sowie-3f9a1c04.mp3` — and not a URL. The hostname is one pull zone for the whole
catalogue and lives in `BUNNY_CDN_HOST`, and the URL a buyer actually gets is
signed per play, so a stored URL would be a stored expiry date. The column is
nullable on purpose: a product whose audio has not been uploaded is a perfectly
good shop listing, it just has no player.

The dashboard draws an `<audio>` pointed at **`/products/:id/stream`**, never at
Bunny. That action authenticates, checks `current_user.purchased?`, and only then
redirects to a freshly signed URL. Three reasons for the indirection rather than
rendering the signed URL straight into the page:

- the token key never reaches the HTML,
- the URL is minted when play is pressed — `preload="none"` — rather than baked
  into a page that may sit open for a day,
- moving a file on the CDN cannot strand a link someone already holds.

`BunnySignedUrlService` implements Bunny's advanced token authentication:
HMAC-SHA256 over the path and the expiry, base64url, prefixed `HS256-`. A
signature that is subtly wrong fails as a 403 from someone else's server rather
than as anything debuggable here, so the spec pins it to the **test vector Bunny
publishes** alongside its own reference implementations rather than to whatever
this code happens to produce.

Two decisions inside it are worth knowing:

- **Six hours, not minutes.** Seeking is a fresh Range request against the same
  signed URL, so a short window would expire mid-recording — the one moment this
  must not break — rather than at a page load, where it would at least be obvious.
- **No IP binding**, though Bunny's scheme offers it. A phone moving from wi-fi to
  mobile data changes address mid-recording, and the buyer would get a 403 for
  doing nothing wrong.

`cdn_path` is validated to characters that survive a URL untouched, because Bunny
signs the path *as it appears in the URL* — a filename needing percent-encoding
would be signed in one form and requested in another. `BunnyStorageService`
already produces paths in that shape, so this now mostly guards the manual
fallback below.

With `BUNNY_CDN_HOST` or `BUNNY_CDN_TOKEN` unset — local development, the test
suite — `Product#streamable?` is false and the library renders exactly as it did
before the CDN existed. Nothing half-works.

### Uploading the audio

The admin form takes the recording itself, not a path to one. Before that, the
owner uploaded through Bunny's dashboard and pasted the resulting path into the
form — two systems to be logged into, and a typo in the paste failed as a **403
the first time a buyer pressed play** rather than as anything visible at the time.

`BunnyStorageService` PUTs the file to `https://{host}/{zone}/{path}` with the
zone's key in an `AccessKey` header. Three things about it are deliberate:

- **Proxied through the app, not sent from the browser.** The storage password is
  a write key for the *whole* zone, so handing it to the page would put it in the
  HTML of every admin screen and the network log of every machine that opened one.
  Rack has already buffered the upload to a tempfile by then, so proxying costs a
  streamed copy rather than memory — nothing reads the file into a string, the
  body and the checksum are both chunked.
- **Uploaded before the record is saved.** A zone that is down or misconfigured
  re-renders the form with everything still in it, instead of quietly saving a
  product whose player never appears. The cost is an orphaned file when the upload
  lands and the save then fails validation, which is much cheaper than the reverse.
- **Filename transliterated, plus a random suffix.** `Nagranie Śpiącej Sowy.mp3`
  becomes `/bajki/nagranie-spiacej-sowy-3f9a1c04.mp3`: transliterated because the
  pull zone signs the path as it appears in the URL, suffixed because two products
  uploaded from the same `nagranie.mp3` would otherwise become one file, silently
  replacing a recording another product still points at.

The folder follows the product's kind — `audioprocesy` or `bajki` — so the zone
reads the way the shop talks about itself and Bunny's own file browser makes sense
without the database open beside it. The map lives in the service rather than on
`Product`, which means no caller ever supplies a path segment: everything about
where a file lands is decided in one class, from a kind the enum has already
narrowed to two values. A product with no kind chosen yet is refused rather than
defaulted, because a guessed folder files the recording somewhere the owner has no
reason to look.

A `Checksum` header carries a SHA256 of the bytes; Bunny hashes what it received
and 400s on a mismatch, which turns a connection dropped near the end into a
refusal rather than a stored file that plays as far as it got. `401` and `404` are
reported separately in the form — one is the wrong password, the other the wrong
zone or region, and from a bare "upload failed" there is no telling which was
pasted wrong.

The form caps uploads at **250 MB** and to audio extensions — not to police the
owner's files but to fail on the obvious mistake, a video or an unrendered project,
before it has been pushed across the wire. Anything sitting in front of the app has
its own, lower limit worth checking first: Cloudflare's free tier stops at 100 MB,
and the upload will die there rather than here.

Replacing a file leaves the old one in the zone. Nothing points at it any more —
the paths are unique — but nothing deletes it either: an app that silently deletes
from the storage zone is a worse thing to own than a few stale files, which Bunny's
own file browser can prune.

`BUNNY_STORAGE_ZONE` and `BUNNY_STORAGE_PASSWORD` (the zone's **FTP & API
password**, not the read-only one and not the CDN token) switch the uploader on.
`BUNNY_STORAGE_HOST` is only needed if the zone is outside Falkenstein —
`ny.storage.bunnycdn.com` and friends; a PUT to the wrong region 404s. With none
of them set the form falls back to a typeable path and says on screen why the
uploader is missing, so local development is not left with a dead field.

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

### Who counts as an admin

One boolean, `users.admin`. There are only ever a couple of people, so it is a
flag rather than a role system, and it is granted from the console:

```sh
bin/rails 'admin:promote[you@example.com]'
bin/rails 'admin:demote[you@example.com]'
bin/rails admin:list
```

`Admin::BaseController` gates every `/admin` screen on it, and the navbar shows
the panel link off the same check, so promoting a second person needs no deploy.

The Google Calendar screen at `/integrations/google_calendar` used to be the
exception: it compared `current_user.email` against `ENV["OWNER_EMAIL"]`, which
allowed exactly one address and made adding a second person a redeploy. It now
uses `admin?` like everything else. **`OWNER_EMAIL` is not a permission** — it is
only where booking and contact mail is delivered and the `reply_to` fallback, and
holding that address grants nothing. `spec/requests/integrations/google_calendar_spec.rb`
pins both halves of that, including the case of a non-admin whose email happens to
match `OWNER_EMAIL`.

It is the one panel screen living outside the `Admin::` namespace, which shows up
in two places. Its sidebar entry in `AdminHelper#admin_sidebar_items` cannot key
its `active` rule off an `admin_`-prefixed controller like the rest, so it matches
`controller_name == "google_calendar"`; and the controller sets `layout "admin"`
explicitly, since it inherits from `ApplicationController` and would otherwise
render the sidebar link's destination with the public navbar and footer. Both are
pinned by specs, along with the sidebar icons resolving — `icon` raises on an
unknown name, so a typo there is a 500 rather than a missing glyph.

### When there is no usable calendar

Two states look identical from the app's side — nobody has ever connected a
calendar, and the grant that was connected has since been revoked or expired —
and `GoogleCalendarService::NotConnected` is raised for both. It is deliberately
**not** a `Google::Apis::Error`: that one means a single call failed and is worth
retrying, while this one is only fixed by a person opening the panel and pressing
connect.

The two nothings arrive differently, which is why the check sits in one place.
`get_credentials` returns `nil` when the token store is empty, and *raises* when
what is stored no longer works — Google answers 400 "Token has been expired or
revoked" the moment the gem tries to mint an access token from a dead refresh
token. Left as they come, the first produced a service with a `nil` authorization
that looked fine until its first API call, and the second escaped as a `Signet`
error nothing up the stack caught.

Callers handle it in the way that suits them:

- **`BookingCalendarService`** swallows it alongside `Google::Apis::Error`, on the
  existing principle that the calendar is a side effect of the booking and must
  never roll back a payment already taken.
- **`BookingsController#load_availability`** renders the page with *no* slots
  available and an explanatory banner (`bookings.calendar.unavailable`), rather
  than the 500 it used to raise. Every slot is shown taken rather than free on
  purpose: with no calendar to check against, "free" is a guess, and a wrong guess
  sells a time the owner is already busy in. The banner lives inside the
  `#availability` div so the `create` turbo stream carries it too.

### Disconnecting always works

`revoke_authorization` deletes through the token store only *after* it has
successfully built credentials, so the case where the row most needs to go — a
grant Google has already dropped — was the one case where it never got that far.
The button 500'd, the row survived, and the panel kept reporting "Połączono" with
no way back.

`destroy` now revokes best-effort and deletes the row itself regardless. Both
failure modes (`400` to the revoke, and a refresh that raises before the revoke)
mean the grant on Google's side is already gone, which is the state the button is
trying to reach anyway.

### The jobs dashboard

Mission Control – Jobs is mounted at `/admin/jobs`, inside the `admin` namespace so
`Admin::BaseController` gates it on the same `admin` flag as every other panel screen.
The engine turns HTTP basic auth on by default and returns `401` until it is either
configured or disabled, which would mean a second password on top of the flag, so
`config/initializers/mission_control_jobs.rb` switches it off and points
`base_controller_class` at `Admin::BaseController` instead.

It renders in the engine's own layout rather than the panel's, so the sidebar is not
on screen once you are there. Its entry in `AdminHelper#admin_sidebar_items` is
therefore the one with no reachable `active` state — it is in the nav to be reachable
at all, not to highlight.

It exists because a Solid Queue backlog is invisible from the app: nothing raises,
nothing is logged, and both a mail outage and a Paddle webhook that never got acted
on look like an ordinary quiet queue. Failed and stuck jobs, the recurring tasks in
`config/recurring.yml`, and whether a worker is running at all are all on that screen.
If it shows jobs ready and no workers, see `SOLID_QUEUE_IN_PUMA` under
[Staging on Render](#staging-on-render).

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

**Path or query string is one mechanism, not two.** `default_url_options` returns
the same `{ locale: :en }` for every route; Rails fills the `:locale` path segment
when the target route has one and appends `?locale=en` when it does not. Nothing
chose a query string for the auth pages — it is what is left when the route has no
slot for it. So on a page rendered in English, `/en/cart` and
`/users/sign_in?locale=en` come from the same line of code.

**The query string is not redundant, and it is not worth removing.** It looks like
dead weight — `session[:locale]` already carries the language onto `/users/sign_in`
for anyone who browsed the public site first, which is what the examples under
*remembering the choice* cover. They all visit `/en/about` before signing in. The
case they miss is someone who lands on a Devise page *directly* — a shared link, a
bookmark, the reset mail below — and switches language there. The session is only
ever written on a locale-scoped route, so on that path the param is the only thing
that carries English to the next page:

```
/users/sign_in            → pl          (fresh session)
/users/sign_in?locale=en  → en, and the sign-up link on it keeps ?locale=en
```

Removing it would also have to be done per call site, since `default_url_options`
cannot see which route it is generating for: 20 places in the Devise and shared
views, plus every link in the admin panel and the integrations screens, which are
unscoped too. Leave it.

**Mails carry it too, and there it is the only thing that can.**
`ApplicationMailer#default_url_options` repeats the controller's rule, because a
mail renders with no request in scope and would otherwise fall back to the
routes-level `locale: nil` — an English mail whose every link came out Polish. The
reset mail was the case that mattered: its button opened the Polish password form
for anyone whose session had gone, which is every recipient on a different device.
`session[:locale]` cannot help there, so the URL has to say it. Devise delivers
inline and the booking and contact mails go through `deliver_later`, but ActiveJob
serialises `I18n.locale` with the job and restores it around `perform`, so the
language survives the queue either way. Covered by
`spec/mailers/devise_mailer_spec.rb`.

## What the browser loads from elsewhere

The short version: **a visitor who only reads the site makes no third-party
request at all**, and the only cookie set is our own session. That is a
deliberate position, not an accident, and it is what keeps the site out of
cookie-banner territory — an ePrivacy consent gate is required for storage that
is not strictly necessary, and there isn't any.

| Thing | When it loads | Consent needed |
| --- | --- | --- |
| Rails session cookie | Always | No — strictly necessary (sign-in, basket, CSRF) |
| Typefaces | Always, from our own server | No — no third party involved |
| Paddle.js | Only when a checkout opens | No — the buyer asked for the payment |
| Google OAuth | Only when "sign in with Google" is clicked | No — cookies are Google's own, set on Google's domain |

There is deliberately **no analytics, no tag manager and no advertising pixel**.
Adding any of them changes the answer in that last column and brings a consent
banner with it, so it is not a small decision.

### Typefaces are self-hosted

Quicksand and Baloo 2 are served out of `app/frontend/fonts` and declared in
`application.css`, not pulled from `fonts.googleapis.com`. The CDN version set no
cookies, so no banner would have covered it, but it did hand Google every
visitor's IP on every page load — which is the transfer the Munich court awarded
damages over in 2022 (LG München I, 3 O 17493/20) and the reason for the German
warning letters that followed.

They are **variable** fonts, so one file covers each family's whole weight range
(Quicksand 300–700, Baloo 2 400–800) rather than one file per weight. Kept from
Google's own subsetting is the latin / latin-ext split, because the
`unicode-range` on each `@font-face` means the English site never downloads the
subset holding ą/ć/ę/ł/ń/ś/ź/ż while the Polish one does. Four files, ~115 KB,
fingerprinted by Vite like any other asset.

Both families are SIL Open Font License 1.1 and the licences ship beside them in
`app/frontend/fonts`. Replacing a family means dropping in the new `.woff2`,
updating the `@font-face` blocks and `--font-sans` / `--font-display` in
`@theme`, and keeping its licence file alongside.

### The one exception: Google avatars

`users.avatar_url` stores whatever `image` the Google OAuth response carried,
which is a `lh3.googleusercontent.com` URL, and `shared/_navbar` renders it
straight into an `<img>`. So a user who signed in with Google does fetch one
image from Google on every page — the same IP transfer the fonts were moved for,
narrowed to people who already chose to involve Google in their sign-in.

It is defensible where it stands and nothing depends on changing it. If it should
go, the fix is to copy the image into Active Storage once at
`User.from_omniauth` rather than to hotlink it, which also survives Google
rotating the URL.

## The production image

`Dockerfile` builds the image Kamal deploys. It is the stock Rails 8 file with the
changes below; everything else there is untouched generator output.

**Node exists only in the build stage.** This is the part that isn't optional: the
app bundles JS and CSS through `vite_rails`, and `vite_ruby`'s rake hook enhances
`assets:precompile` to run `vite build`. A Ruby-only image cannot precompile, so the
build stage lifts `node` and `npm` out of the official Node image with `COPY --from`
rather than compiling them from source, which costs seconds instead of minutes. The
Node image is pinned to `bookworm` on purpose — its glibc has to be no newer than the
Ruby base image's, or the copied binary won't link. The final stage never copies any
of it, so the shipped image has no Node in it at all.

**`npm ci` runs once, in its own layer.** `package.json` and `package-lock.json` are
copied before the app code so editing a view doesn't reinstall the JS tree. That
means the `vite:install_dependencies` half of the precompile hook would be a second,
uncached `npm ci` that wipes the first one, so `VITE_RUBY_SKIP_ASSETS_PRECOMPILE_INSTALL=true`
turns it off. `--include=dev` is required and easy to lose: `vite`, `tailwindcss` and
`vite-plugin-ruby` are all devDependencies, and `RAILS_ENV=production` is enough to
make npm skip them, which fails the build with a missing-vite error. `node_modules`
is deleted once the bundles are written.

**Smaller odds and ends.** `BUNDLE_WITHOUT` excludes `test` alongside `development`
— nothing in the image runs specs, so rspec, capybara and selenium don't belong in
it. `RUBY_YJIT_ENABLE=1` turns the JIT on. apt and npm downloads use BuildKit cache
mounts, so repeat builds skip the network. A `HEALTHCHECK` curls `/up`; it targets
`HTTP_PORT` (Thruster's own listener, default 80) rather than `PORT`, which is the
Puma port Thruster proxies *to*.

**Secrets come from ENV, not encrypted credentials.** Every secret this app reads —
database, Google, Paddle, Brevo, Bunny, SMTP — comes from environment variables, and
`secret_key_base` is no exception, and `config/credentials.yml.enc` is unused (there is
no `config/master.key`). Rails checks `ENV["SECRET_KEY_BASE"]` before it tries to decrypt
credentials, so setting it is all that's needed.

There are two dotenv files, both gitignored. `.env` is development: `dotenv-rails` loads
it automatically. `.env.production` holds the deployed values, and nothing loads it
automatically — `dotenv-rails` is a development/test gem that `BUNDLE_WITHOUT` drops from
the image, so the container reads no dotenv file at all. Production values reach it as
real environment variables instead:

- Kamal: `.kamal/secrets` greps them out of `.env.production`, and `config/deploy.yml`
  lists each name under `env.secret`. A secret that isn't in both files doesn't ship.
- plain Docker: `docker run --env-file .env.production …`, which is also why the
  non-secret settings in `env.clear` have to be passed by hand in that case.

Asset precompilation in the build stage doesn't need the real value — `SECRET_KEY_BASE_DUMMY=1`
makes Rails invent a throwaway one — which is why a missing secret only shows up at
container start, as `db:prepare` aborting with ``Missing `secret_key_base` for 'production'``.
`bin/rails secret` generates a replacement; changing it invalidates every existing session
and signed cookie.

**Postgres runs on the same host, as a Kamal accessory.** `config/deploy.yml` boots
`postgres:17` next to the app rather than pointing at a managed database elsewhere. The
reason is Solid Cache, Solid Queue and Solid Cable: they all sit in the same Postgres
as the app data, so every cache read and every job poll is a SQL round trip. The distance
to the database sets the floor on request latency — trivial over the local docker
network, expensive to another datacentre.

The app never crosses the public interface to reach it. Kamal puts both containers on
its own docker network, where the accessory answers to `sleep_puzzle-db`, which is what
`DATABASE_HOST` is set to. The `127.0.0.1:5432:5432` mapping exists only so `psql` and
`pg_dump` work over an SSH session on the host; it is not reachable from outside.

`directories: data:/var/lib/postgresql/data` bind-mounts the cluster onto the host, so
rebooting the accessory or moving to a newer Postgres image doesn't take the data with
it. Note that a major-version bump still needs a dump and restore — the on-disk format
isn't compatible across majors, and the container will refuse to start on a data
directory it doesn't recognise.

Order matters once, on a fresh server: `kamal accessory boot db` before `kamal deploy`,
or `db:prepare` in the entrypoint has nothing to connect to.

**Backups are the part the single-server setup doesn't give you.** Losing the VPS loses
the database with it, so a nightly `pg_dump` pushed off the server is not optional. Run it from the accessory rather than the app container: the image ships
the bookworm `postgresql-client` (15), and `pg_dump` refuses to dump a newer server, so a
dump from inside the app container will fail against Postgres 17. OVH's VPS backup option
is worth having as well, but a snapshot of a live cluster is crash-consistent at best and
is not a substitute for a dump you have actually restored once.

**Migrations on boot.** `bin/docker-entrypoint` still runs `db:prepare`, but only
when the command is `./bin/rails server` and `SKIP_DB_PREPARE` is unset. Set that
variable if you ever split jobs onto their own host or run a second web server, so
one container owns the schema change instead of all of them racing.

`.dockerignore` additionally drops `public/vite*` (stale local bundles that the build
regenerates anyway), `spec/`, `coverage/` and editor config, purely to keep the build
context small.

## Staging on Render

Staging is a Docker web service on Render with Postgres on Supabase, set up in the
dashboard rather than from a blueprint in this repo — the app is one image and a
handful of environment variables, and a `render.yaml` that only takes effect through
Render's Blueprint flow was one more thing to keep in sync. What isn't obvious from
the dashboard, though, is below.

**`DATABASE_URL` is the whole database configuration.** Solid Cache, Solid Queue and
Solid Cable keep their tables in the primary database rather than in three of their
own, which is why `config/database.yml` has a single `production` entry, why
`config/cache.yml` and `config/cable.yml` name no database, and why the solid_* tables
arrive through `db/migrate` like any others. Cache writes and job polling therefore
share a database with application data — noise at this size, and it means any free
Postgres with a single database is enough to run staging.

Use Supabase's **session pooler** string: port 5432, `aws-<region>.pooler.supabase.com`,
user `postgres.<project-ref>`. The direct `db.<ref>.supabase.co` connection is IPv6-only
without the paid IPv4 add-on, and the transaction pooler on 6543 doesn't support
prepared statements, which Rails uses by default. On 6543 you would also need
`prepared_statements: false` and `advisory_locks: false` in `config/database.yml`, the
latter because migrations take a session-level lock that pooler can't hold.

**Set `HTTP_PORT=10000` and `PORT=3000`.** Thruster listens on `HTTP_PORT` and proxies
to Puma on `PORT`. Render injects its own `PORT`, which Puma would take, leaving
Thruster on 80 where nothing is probing. Splitting them explicitly is what makes the
health check pass.

**Don't generate fresh `AR_ENCRYPTION_*` keys.** All three have to match whatever
produced the data. Fresh ones give you an environment that boots and then can't read a
single encrypted column out of a production dump. `SECRET_KEY_BASE` is the opposite —
generate one, staging has no sessions worth keeping.

**Set `SOLID_QUEUE_IN_PUMA=true`.** `config/puma.rb` only starts the Solid Queue
supervisor when this is set, and Kamal sets it in `config/deploy.yml` — so on Render
it is easy to miss, and missing it breaks two things that look unrelated. Contact and
booking mail goes out through `deliver_later`, and Paddle's webhooks are handled by
`Pay::Webhooks::ProcessJob`, which is what runs `BookingConfirmationService`. With no
worker, the webhook still arrives and validates and the `Pay::Webhook` row is still
written; the job that acts on it just never runs, so Paddle shows the transaction
paid while the booking sits at "pending". Nothing errors — a queue with no worker
looks exactly like a queue with nothing to do, which is what `/admin/jobs` is mounted
for. The supervisor forks a worker, a dispatcher and a scheduler, so expect a few more
Postgres connections than Puma alone.

Keep `PADDLE_BILLING_ENVIRONMENT=sandbox`, and point SMTP and Brevo at test accounts:
staging sends real mail to real people if handed production credentials.

Migrations need nothing special. `bin/docker-entrypoint` runs `db:prepare` whenever the
command ends in `./bin/rails server`, which the image's `CMD` does, Thruster in front
included.

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
      state. The library plays what was bought through an `<audio>` element
      pointed at `/products/:id/stream` — see *Delivering the audio* above

### Newsletter

**Decided: buy, not build.** Brevo holds the list and the campaign editor. That
deliberately keeps consent records, confirmed opt-in, unsubscribe links, bounce
handling and deliverability on Brevo's side rather than ours, and it means there is
no subscriber model, no issue model and no sending code to write here.

- [x] **Sign-up form on the home page.** Built. `NewsletterSignup` validates the
      address, `NewsletterSubscriptionsController` posts it to Brevo through
      `BrevoSubscriptionService`, and the form swaps for the thank-you state inside
      its own Turbo frame — the visitor is at the bottom of a long page, so a full
      reload would put them back at the top.

**It posts to the double opt-in endpoint**, `/v3/contacts/doubleOptinConfirmation`,
rather than plain `/contacts`. That is the difference between Brevo mailing a
confirmation link and us adding someone to a marketing list because an address was
typed into a box, and it is why the thank-you says *check your inbox* rather than
*you are subscribed*: until they follow Brevo's link they are not on the list.
Nothing about them is stored here, so there is no subscriber model and no
unsubscribe route of ours to keep in step with Brevo's.

**Three environment variables, all required** — `configured?` is false without any
one of them, and an unconfigured Brevo fails the submission loudly rather than
showing a thank-you for an address that went nowhere:

| | |
| --- | --- |
| `BREVO_API_KEY` | authorises the call |
| `BREVO_LIST_ID` | what they are subscribing *to* |
| `BREVO_DOI_TEMPLATE_ID` | the confirmation mail — a DOI template, not a campaign one |

Two behaviours worth knowing. An address **already on the list** is treated as
success: Brevo answers `duplicate_parameter`, and saying so would tell anyone who
asks which addresses are subscribed. And there is **no Turnstile on this form**,
unlike the contact one — that puts mail in the owner's inbox on every submission,
whereas this hands an address to Brevo, which mails a link only its owner can act
on. The rate limit (3/minute, tighter than contact's 5) is the proportionate
control; a challenge on a one-field box mid-page is not.

### Missing sections on the home page

The design's home screen runs HERO / TRUST BAR / O MNIE TEASER / PACKAGES TEASER /
JAK TO DZIALA / AUDIO SHOP TEASER / MEDIA-PODCASTS / BLOG TEASER / NEWSLETTER. The
app builds hero, the trust bar (as the `home.stats` collection), about, process,
packages, audio and the newsletter form. What is missing:

- [ ] Media / podcast strip

Two things the design draws are deliberately not being built: the **kicker badge**
above the hero headline (`L.home.kicker`), and the **blog teaser**, which is parked
along with the blog itself.

### Cross-cutting

- [x] **Navbar, footer and the home page's CTAs** now read from `nav.*` in
      `pl.yml`/`en.yml` rather than being hardcoded Polish. Copy the owner writes
      still lives in the CMS, and a block with no English version falls back to
      Polish on purpose — that is content waiting to be translated, not a bug.
- **Decided: the admin panel and the Google Calendar integration screen stay
      Polish-only.** `integrations/google_calendar/show` and everything under
      `admin/` hold Polish literals on purpose. Both are staff-facing and the staff
      is Polish, so there is nothing to translate and no gap here.
- **Decided: the two stock-English Devise screens stay as they are** —
      `confirmations/new` and `unlocks/new`, plus the `confirmation_instructions`
      and `unlock_instructions` mails. `:confirmable` and `:lockable` are both
      switched off in `User`, so nothing ever reaches them.

- [x] **Buyer-facing toast copy is translated.** `paddle_controller.js` and
      `toast_controller.js` are Stimulus controllers, so they have no `t()` — the
      strings are resolved server-side and handed over as values instead:
      `shared/_paddle_checkout` passes the five `paddle.*` keys, and
      `Toast::Component` passes `toast.close` for the close button's `aria-label`.
      Adding buyer-facing copy to either controller means adding a value, not a
      literal.

- [x] **Paddle errors surface now.** `checkout.error` used to fall through the
      switch, so a declined card or a rejected quantity produced nothing — not a
      toast, not even a console line, which is why the max-quantity rejection had
      to be diagnosed by hand. It now logs the whole event and shows Paddle's own
      message in an error toast, falling back to `paddle.error_fallback` when the
      payload carries no message (Paddle has moved that field between versions, so
      `#errorDescription` tries each plausible spot). It deliberately does *not*
      abandon the pending record: the overlay stays open and the buyer can retry
      in it, and `checkout.closed` still releases the record if they give up.

- [x] **PL/EN switcher.** In the path — see *Two languages, two addresses* above.
- [x] **Dead links.** All wired. Navbar "Blog" stays commented out rather than
      pointing at nothing, which is the right shape for as long as the blog is
      parked.
- [x] **CMS coverage.** Every page that exists is editable: `content_blocks.yml`
      declares `home`, `packages`, `about`, `shop`, `cart`, `dashboard`, `terms`,
      `footer` and `contact`. This stays true only if each new page adds its own
      entry, followed by `bin/rails content_blocks:sync`.

      **Which of the two a string belongs in** is not always obvious, and the line
      is *who owns the wording*, not where it appears. Chrome the owner would never
      rewrite — the navbar, the footer's column headings, the locale switcher —
      is `nav.*` in `pl.yml`/`en.yml`. Anything she might reword is CMS, even when
      it is a two-word button: `home.packages.details` ("Zobacz szczegóły" on a
      package card) went to the CMS for exactly that reason. Arrows and other
      decoration stay in the template either way, so rewording a label cannot lose
      them.
- [x] **Delivering what was bought.** Done — the audio is on Bunny, and
      `/dashboard` plays it. The check is both ours *and* a signed CDN URL: the
      app authorises, Bunny enforces. See *Delivering the audio* above. What is
      left is per-product: uploading the files and filling in each `cdn_path` in
      the admin panel. A product without one still sells, it just has no player.

### Parked

- **Blog** and **Wpis na blogu** — designed (list and post screens) but deliberately
  not being built for now. Nothing in the app depends on them.

## Continuous integration

`.github/workflows/ci.yml` runs on every pull request and on pushes to `main`
and `development`. Three jobs, all of which you can reproduce locally:

| Job | Command |
| --- | --- |
| `scan_ruby` | `bin/brakeman --no-pager` and `bin/bundler-audit` |
| `lint` | `bin/rubocop -f github` |
| `test` | `bin/rails db:test:prepare && bundle exec rspec` |

`development` is in the push triggers deliberately. It used to be absent, and
because feature work happens there and only reaches `main` through one large
merge, nothing was checked until after that merge landed — 161 RuboCop offenses
accumulated on the branch and all surfaced at once on `main`, on a commit that
was already merged. Checking `development` on push moves that feedback to the
branch where the code was written.

There is no `system-test` job. There used to be, but `spec/system` was removed
in `054908d` and a job pointed at a missing directory can only ever be red.
Capybara, selenium-webdriver and `spec/support/capybara.rb` are all still in
place, so restoring it is adding the job back once a system spec exists.

Note that `bin/brakeman` does *not* pass `--ensure-latest`. That flag makes the
scan exit non-zero whenever a newer Brakeman has been released, which turns an
upstream release into a red build on code that did not change. Dependabot keeps
the gem current; the scanner's job here is to fail on warnings, not on its own
version.

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
