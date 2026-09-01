# Sleep Puzzle

A Rails 8 site in Polish and English. It sells sleep recordings and consultations,
takes payments through Paddle, serves the audio from Bunny CDN, and lets the owner
edit the copy herself.

## Setup

You need Ruby 4.0.5 (see `.ruby-version`), PostgreSQL, **libvips**
(`brew install vips`, or `apt-get install libvips`) - Active Storage resizes CMS
images with it, and without it uploads succeed but every image URL 500s - and
**ffmpeg** (`brew install ffmpeg`), which cuts the shop's 30-second previews.
Without ffmpeg an audio upload still succeeds and the product still sells; it
just gets no preview, and the reason is in the log. The Dockerfile installs
both, so these are local steps only.

```sh
cp .env.example .env    # every variable is documented in there
bin/setup
bin/dev
```

Only the database name has a default; `DATABASE_URL` overrides the `DATABASE_*`
variables and is how CI points at its own Postgres. One database per environment -
Solid Cache, Solid Queue and Solid Cable keep their tables in it too.

## Tests and CI

`.github/workflows/ci.yml` runs on pull requests and on pushes to `main` and
`development`. All three jobs run locally:

| Job | Command |
| --- | --- |
| `scan_ruby` | `bin/brakeman --no-pager` and `bin/bundler-audit` |
| `lint` | `bin/rubocop -f github` |
| `test` | `bin/rails db:test:prepare && bundle exec rspec` |

There is no system-test job - `spec/system` was removed in `054908d`. Capybara is
still set up, so it can come back once a system spec exists.

## How it fits together

* **Content** - everything the owner can edit is declared in
  `config/content_blocks.yml` (see below) and edited at `/admin/content_blocks`.
* **Shop** - no price is stored here. A `Product` holds a `paddle_price_id` and
  every figure on screen is read back from Paddle, so a product whose price can't
  be read renders with no add button.
* **Cart** - `session["cart"]`, a set of product ids. No quantities: everything
  sold is a file. Anything the buyer already **claims** is kept out of the cart,
  the order and the total.
* **Checkout** - Paddle's overlay, so there is no payment screen of our own.
  `OrdersController#create` makes a pending order, and the
  `transaction.completed` webhook marks it paid. Closing the overlay fires no
  webhook, so the browser reports it to `orders#abandon`, which puts the lines
  back in the cart.
* **The window between paying and the webhook** - an order is `pending` from the
  moment the overlay opens until Paddle reports on it, and a digital file has to
  stay out of the shop for that whole window or it can be bought and charged for
  twice. So ownership is two questions, not one: `User#purchased?` is *paid and
  streamable*, and `User#claimed?` - paid **or** pending - is what the shop
  button, the cart, and checkout all read. The shop shows a neutral "Płatność w
  trakcie" pill, `/dashboard` lists the file above the library with no player,
  the cart says why it is not being charged for, and `orders#show` streams itself
  the outcome over `turbo_stream_from @order` rather than asking for a refresh.
* **Letting go of a pending order** - because pending now blocks a re-purchase,
  something must release one that never gets paid, or the file is locked for that
  buyer forever. `OrderPaymentFailureService` handles the `payment_failed` and
  `canceled` webhooks (with the same 15-minute grace as bookings, since a decline
  leaves the buyer in the checkout to try another card) via
  `FailPendingOrderJob`, and `ReleaseAbandonedOrdersJob` sweeps anything still
  pending after an hour. The sweep marks the order `canceled` rather than
  deleting it, unlike `orders#abandon`, so a late `transaction.completed` still
  finds a row to mark paid instead of logging money nobody can account for.
* **Audio** - files live on Bunny behind a token-authenticated pull zone.
  `Product#cdn_path` stores the path, never a URL. `/products/:id/stream` checks
  ownership and redirects to a URL signed for six hours. Uploads go through the
  admin form, proxied by the app so the zone's write key never reaches the
  browser. **A product cannot be published without a file** - the validation
  refuses it, and `Product.published` excludes any row that was published without
  one anyway, so the shop never offers something there is nothing to deliver for.
* **Accounts** - Devise, plus Google OAuth. A Google sign-up has no password, and
  `User#password_set?` is what keeps `/users/edit` from demanding one.
* **Calendar** - `/integrations/google_calendar` is two steps: connect the Google
  account, then pick which of its calendars bookings are written to. The pick is
  stored on the integration row, so changing calendars is a dropdown rather than
  a redeploy. Only calendars the grant can write to are offered - a subscribed
  one cannot hold a booking. Connected-but-unpicked is a real state and the panel
  says so; the app treats it as `NoCalendarSelected`, a kind of `NotConnected`,
  so a half-finished setup degrades the same way a missing one does instead of
  failing a payment. `GOOGLE_CALENDAR_ID` is now only the pre-panel fallback and
  can be dropped from the environment once a calendar has been picked.
* **Availability reads the calendar both ways** - `GoogleCalendarService#busy`
  lists the events rather than asking freebusy, so anything the owner writes into
  the calendar by hand blocks the slots it covers. Freebusy is the obvious API
  here and the wrong one: it drops every event marked transparent, and Google
  Calendar marks all-day events transparent by default, so a fortnight of "urlop"
  entered the normal way blocked nothing and left every slot inside it on sale.
  Transparency is ignored rather than honoured, because an event wrongly read as
  busy costs one visible blocked slot while one wrongly read as free sells a time
  she is not available. Nothing is cached - the list is fetched per render.
* **Admin** - one boolean, `users.admin`. `bin/rails 'admin:promote[you@example.com]'`
  (also `admin:demote`, `admin:list`). `OWNER_EMAIL` is an inbox, not a permission.
* **Dashboards** - `/admin/jobs` (Solid Queue) and `/admin/db` (PgHero). Both bring
  their own layout, so the sidebar is off screen once you're in them.
* **Languages** - Polish is the bare path, English is the same page under `/en`.

## Editable content

`config/content_blocks.yml` **is the schema** - no Ruby names any field. Meaning
comes from depth: level 1 is a page, level 2 (under `sections:`) a section, level 3
(under `fields:`) a field.

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

Read it in a view with `content_block("footer.brand.tagline")` - `content_image`
for `image` fields, `content_items` for a collection. That works as soon as the
lines are in the YAML: with no row in the database the helper renders the declared
`default:`.

`bin/rails content_blocks:sync` pre-creates a blank row per declared key and
populates collection defaults. It is optional for plain and rich fields - the panel
creates the row the first time the owner saves - and idempotent, so it never touches
copy anyone has written. Nothing runs it on deploy.

* Types are `plain`, `rich` (Trix) or `image` (one upload, not one per language).
* `label:` is required at every level; `default:` is optional, and `en` falls back
  to `pl`.
* A section with no `fields:` can hold a `collection:` instead - a repeating list
  the owner can add to (see `home.stats`). A collection with no rows renders its
  declared defaults, and they are materialised the first time anyone adds to it.
* Order follows the file. Unknown types and missing labels raise at boot; an
  unknown key raises in development and test and is ignored in production.

New pages must add their own entry, or they aren't editable. Chrome the owner would
never rewrite (navbar, footer headings, the language switcher) belongs in `nav.*` in
`pl.yml`/`en.yml` instead; anything she might reword is CMS, even a two-word button.

## Deploying

Production is Kamal on a single VPS with Postgres as an accessory; staging is a
Docker service on Render with Postgres on Supabase, configured in the dashboard
rather than from a blueprint in this repo.

Every secret comes from ENV - there is no `config/master.key`, and
`config/credentials.yml.enc` is unused. `.env` is development only; nothing loads
`.env.production` automatically, so Kamal greps it in `.kamal/secrets` and each name
also has to be listed under `env.secret` in `config/deploy.yml`. A secret missing
from either file doesn't ship.

TLS is Cloudflare's origin certificate, not Let's Encrypt. The record is proxied,
so port 80 never reaches the VPS and the ACME challenge can't complete; `proxy/ssl`
names two secrets whose values are the PEM bodies, and Kamal uploads them to
kamal-proxy on deploy. The zone must be on **Full (strict)** - anything less and
Cloudflare accepts an unverified origin.

That forces every domain this VPS serves into **one Cloudflare account**. Kamal takes
a single `certificate_pem`/`private_key_pem` pair for the whole proxy, so one cert has
to cover every name in `proxy/hosts`; Cloudflare will only put a hostname on an origin
cert if its zone sits in the issuing account. Two accounts means two certs, and there
is nowhere to put the second. Adding a domain therefore means moving its zone in
alongside the others and reissuing the cert with both names on it, not issuing a
second one. Check what the current cert actually covers before pointing a new name at
the origin - a host in `proxy/hosts` that the cert omits answers every request with a
Cloudflare 526, and it fails at cutover rather than at deploy:

```sh
openssl x509 -in .kamal/cloudflare-origin.pem -noout -ext subjectAltName
```

Turnstile is the exception and stays portable: a widget's hostname list is just a list,
so the domain does not have to be a zone on that account, or on Cloudflare at all.

**A second domain that only redirects stays out of all of this.** `sleep-puzzle.com`
is not in `proxy/hosts` and not on the origin cert on purpose: a Cloudflare redirect
rule answers it at the edge with a 301 to `sleeppuzzle.com`, so it never opens a
connection to the VPS and never needs a certificate the VPS holds. Putting it in
`proxy/hosts` instead would force it onto the origin cert and spend a round trip to
Poland to emit a `Location` header.

Two things make the edge redirect work, and both are easy to miss:

* The zone still has to be **in Cloudflare, in the same account** - not for the
  origin cert, but so Universal SSL issues an edge certificate. Without it
  `https://sleep-puzzle.com` throws a browser cert warning *before* anything gets a
  chance to redirect, and the redirect rule never runs.
* A redirect rule needs a proxied record to intercept, but there is no origin to
  point one at. Use a placeholder that is orange-clouded and unroutable - an `A` to
  `192.0.2.1` (TEST-NET-1) or an `AAAA` to `100::`, for the apex and for `www`.
  Cloudflare answers before it ever tries to connect. Pointing the record at the
  VPS instead redirects nothing - DNS cannot express a 301 - and kamal-proxy
  rejects the unknown SNI, so it surfaces as a 525 rather than as anything that
  hints at the cause.

The rule itself lives on the **`sleep-puzzle.com` zone**, not the `sleeppuzzle.com`
one. Rules are per-zone and only see traffic for the zone they sit on; the same rule
added to the canonical zone redirects it to itself, which is an infinite loop.
Nothing else is served from the redirecting zone, so it matches **all incoming
requests** rather than a filter expression:

| field | value |
| --- | --- |
| type | dynamic |
| expression | `concat("https://sleeppuzzle.com", http.request.uri.path)` |
| status | 301 |
| preserve query string | on |

Dynamic, not static: a static redirect goes to one fixed URL, so every deep link
lands on the home page. `http.request.uri.path` is the path *without* the query, so
the toggle is what carries `?utm_source=...` across - it is not redundant with the
expression. Use `http.request.uri` instead and it already includes the query, in
which case leave the toggle off or the query gets appended twice.

Keep it a 301 in one direction only. `sleeppuzzle.com` is canonical in more places
than DNS: `APP_HOST` in `config/deploy.yml` pins both the mailer link host and the
OAuth `redirect_uri`, which has to match an authorised redirect URI in the Google
console exactly (`https://sleeppuzzle.com/users/auth/google_oauth2/callback`).
Changing `APP_HOST` without changing it there fails as `redirect_uri_mismatch` at
sign-in, not at deploy.

`forward_headers: true` is load-bearing: kamal-proxy stops passing `X-Forwarded-*`
once SSL is on, and without the real client IP every `rate_limit` in the app shares
one bucket.

On a fresh server, `kamal accessory boot db` before `kamal deploy`, or `db:prepare`
has nothing to connect to. **Back up separately** - losing the VPS loses the
database. Run `pg_dump` from the accessory, not the app container, whose
`postgresql-client` is too old to dump Postgres 17.

## Things that will bite you

* **`SOLID_QUEUE_IN_PUMA` must be set** anywhere Kamal isn't. Without a worker,
  mail and Paddle webhooks queue silently and a paid booking stays "pending".
  Nothing errors - that's what `/admin/jobs` is for. It now also strands orders:
  a pending order holds its files out of the shop, and both the release job and
  the abandoned-order sweep are jobs, so with no worker a buyer whose payment
  never landed can never buy those files again.
* **On Render, set `HTTP_PORT=10000` and `PORT=3000`.** Thruster listens on the
  first and proxies to Puma on the second; Render's injected `PORT` otherwise
  leaves Thruster where nothing is probing.
* **Never generate fresh `AR_ENCRYPTION_*` keys** for an environment with data -
  it will boot and then fail to read a single encrypted column. `SECRET_KEY_BASE`
  is the opposite: generate one, it only invalidates sessions.
* **Use Supabase's session pooler** (port 5432). The direct connection is
  IPv6-only, and the 6543 pooler doesn't support prepared statements.
* **Mail goes over Brevo's HTTP API when `BREVO_API_KEY` is set**, because Render
  blocks outbound SMTP and it hangs rather than failing. `bin/rails mail:check`
  tells the failure modes apart.
* **`routes.default_url_options[:locale] = nil` is load-bearing.** An optional
  leading dynamic segment swallows the first positional argument, so without it
  `product_path(product)` raises `missing required keys: [:id]`.
* **Sentry is production-only on purpose.** It patches `Net::HTTP` on init, which
  breaks specs that stub it, and `enabled_environments` doesn't help.
* **Cap an `auto-fit` grid on the grid, not on the track.** The card grids in the
  shop and under a product use `minmax(240px, 1fr)`, so with fewer cards than a
  row holds the tracks share the whole width and one product stretches a tile
  across 1240px. The views cap the grid's own `max-width` from the collection
  size instead. Putting a definite max in the `minmax()` looks equivalent but
  isn't - the repetition count is computed from the max when it's definite, which
  silently drops a full row from four columns to three.
* **PgHero query stats need `pg_stat_statements`**, which a stock local Postgres
  doesn't preload. Everything else on that dashboard works without it.

## Privacy

A visitor who only reads the site makes **no third-party request at all**, and the
only cookie is our own session - so there is no consent banner. Fonts are
self-hosted, Paddle.js loads only when a checkout opens, and there is deliberately
no analytics, tag manager or ad pixel. Adding one changes that.

The single exception is `users.avatar_url`, which hotlinks a Google avatar for users
who signed in with Google.

## Roadmap

Left to do:

- [ ] Media / podcast strip on the home page
- [ ] Per-product: upload each audio file. A product cannot be published without
      one, so anything still missing its file is a draft rather than a listing.

Decided against, so they don't get re-litigated:

* **The newsletter is bought, not built** - Brevo holds the list, the double opt-in
  and the unsubscribe, so there is no subscriber model here.
* **No buyer-facing purchase history** - Paddle is Merchant of Record and emails the
  receipt. The dashboard library answers the question buyers actually ask.
* **The admin panel and the calendar screen stay Polish-only** - staff-facing, and
  the staff is Polish.
* **The hero kicker badge and the blog teaser** are not being built.
* A block with no English version falls back to Polish on purpose. That's content
  waiting to be translated, not a bug.
