# Sleep Puzzle

A Rails 8 site in Polish and English. It sells sleep recordings and consultations,
takes payments through Paddle, serves the audio from Bunny CDN, and lets the owner
edit the copy herself.

## Setup

You need Ruby 4.0.5 (see `.ruby-version`), PostgreSQL, and **libvips**
(`brew install vips`, or `apt-get install libvips`) — Active Storage resizes CMS
images with it, and without it uploads succeed but every image URL 500s. The
Dockerfile installs it, so this is a local step only.

```sh
cp .env.example .env    # every variable is documented in there
bin/setup
bin/dev
```

Only the database name has a default; `DATABASE_URL` overrides the `DATABASE_*`
variables and is how CI points at its own Postgres. One database per environment —
Solid Cache, Solid Queue and Solid Cable keep their tables in it too.

## Tests and CI

`.github/workflows/ci.yml` runs on pull requests and on pushes to `main` and
`development`. All three jobs run locally:

| Job | Command |
| --- | --- |
| `scan_ruby` | `bin/brakeman --no-pager` and `bin/bundler-audit` |
| `lint` | `bin/rubocop -f github` |
| `test` | `bin/rails db:test:prepare && bundle exec rspec` |

There is no system-test job — `spec/system` was removed in `054908d`. Capybara is
still set up, so it can come back once a system spec exists.

## How it fits together

* **Content** — everything the owner can edit is declared in
  `config/content_blocks.yml` (see below) and edited at `/admin/content_blocks`.
* **Shop** — no price is stored here. A `Product` holds a `paddle_price_id` and
  every figure on screen is read back from Paddle, so a product whose price can't
  be read renders with no add button.
* **Cart** — `session["cart"]`, a set of product ids. No quantities: everything
  sold is a file. Anything the buyer already owns is kept out of the cart, the
  order and the total.
* **Checkout** — Paddle's overlay, so there is no payment screen of our own.
  `OrdersController#create` makes a pending order, and the
  `transaction.completed` webhook marks it paid. Closing the overlay fires no
  webhook, so the browser reports it to `orders#abandon`, which puts the lines
  back in the cart.
* **Audio** — files live on Bunny behind a token-authenticated pull zone.
  `Product#cdn_path` stores the path, never a URL. `/products/:id/stream` checks
  ownership and redirects to a URL signed for six hours. Uploads go through the
  admin form, proxied by the app so the zone's write key never reaches the
  browser. **A product cannot be published without a file** — the validation
  refuses it, and `Product.published` excludes any row that was published without
  one anyway, so the shop never offers something there is nothing to deliver for.
* **Accounts** — Devise, plus Google OAuth. A Google sign-up has no password, and
  `User#password_set?` is what keeps `/users/edit` from demanding one.
* **Admin** — one boolean, `users.admin`. `bin/rails 'admin:promote[you@example.com]'`
  (also `admin:demote`, `admin:list`). `OWNER_EMAIL` is an inbox, not a permission.
* **Dashboards** — `/admin/jobs` (Solid Queue) and `/admin/db` (PgHero). Both bring
  their own layout, so the sidebar is off screen once you're in them.
* **Languages** — Polish is the bare path, English is the same page under `/en`.

## Editable content

`config/content_blocks.yml` **is the schema** — no Ruby names any field. Meaning
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

Read it in a view with `content_block("footer.brand.tagline")` — `content_image`
for `image` fields, `content_items` for a collection. That works as soon as the
lines are in the YAML: with no row in the database the helper renders the declared
`default:`.

`bin/rails content_blocks:sync` pre-creates a blank row per declared key and
populates collection defaults. It is optional for plain and rich fields — the panel
creates the row the first time the owner saves — and idempotent, so it never touches
copy anyone has written. Nothing runs it on deploy.

* Types are `plain`, `rich` (Trix) or `image` (one upload, not one per language).
* `label:` is required at every level; `default:` is optional, and `en` falls back
  to `pl`.
* A section with no `fields:` can hold a `collection:` instead — a repeating list
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

Every secret comes from ENV — there is no `config/master.key`, and
`config/credentials.yml.enc` is unused. `.env` is development only; nothing loads
`.env.production` automatically, so Kamal greps it in `.kamal/secrets` and each name
also has to be listed under `env.secret` in `config/deploy.yml`. A secret missing
from either file doesn't ship.

On a fresh server, `kamal accessory boot db` before `kamal deploy`, or `db:prepare`
has nothing to connect to. **Back up separately** — losing the VPS loses the
database. Run `pg_dump` from the accessory, not the app container, whose
`postgresql-client` is too old to dump Postgres 17.

## Things that will bite you

* **`SOLID_QUEUE_IN_PUMA` must be set** anywhere Kamal isn't. Without a worker,
  mail and Paddle webhooks queue silently and a paid booking stays "pending".
  Nothing errors — that's what `/admin/jobs` is for.
* **On Render, set `HTTP_PORT=10000` and `PORT=3000`.** Thruster listens on the
  first and proxies to Puma on the second; Render's injected `PORT` otherwise
  leaves Thruster where nothing is probing.
* **Never generate fresh `AR_ENCRYPTION_*` keys** for an environment with data —
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
* **PgHero query stats need `pg_stat_statements`**, which a stock local Postgres
  doesn't preload. Everything else on that dashboard works without it.

## Privacy

A visitor who only reads the site makes **no third-party request at all**, and the
only cookie is our own session — so there is no consent banner. Fonts are
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

* **The newsletter is bought, not built** — Brevo holds the list, the double opt-in
  and the unsubscribe, so there is no subscriber model here.
* **No buyer-facing purchase history** — Paddle is Merchant of Record and emails the
  receipt. The dashboard library answers the question buyers actually ask.
* **The admin panel and the calendar screen stay Polish-only** — staff-facing, and
  the staff is Polish.
* **The hero kicker badge and the blog teaser** are not being built.
* A block with no English version falls back to Polish on purpose. That's content
  waiting to be translated, not a bug.
