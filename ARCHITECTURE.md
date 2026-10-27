# Sleep Puzzle — Architecture Reference

> This document describes the **current** implementation as-is, for the purpose of a
> possible rewrite into a React/Next.js frontend with a separate backend. It is a
> factual map of what exists, not a proposal. Product intent lives in
> [`PRODUCT.md`](PRODUCT.md); the visual system lives in [`DESIGN.md`](DESIGN.md);
> the editable-copy schema lives in [`config/content_blocks.yml`](config/content_blocks.yml)
> and [`docs/content-blocks.md`](docs/content-blocks.md).

---

## 1. What the system is

A **Rails 8.1 monolith** storefront for a children's-sleep consultant. It sells two
things through **Paddle** (Merchant of Record):

1. **Audio** — "audioprocesses" (guided multi-chapter audio for parents) and
   "bedtime stories" (single recordings for children), streamed from a signed Bunny
   CDN, with optional 30-second public previews/trailers.
2. **Consultation packages** — 1:1 sessions booked against the owner's **real Google
   Calendar** availability, held during checkout, and confirmed by webhook.

It is **bilingual** (Polish bare paths, English under `/en`), and every public word,
heading, image and repeating list is an **editable content block** the owner changes
in an admin panel without a redeploy.

There is **no separate frontend** today. The browser talks to Rails over HTML +
Turbo Streams; JavaScript is progressive enhancement (Stimulus), not a client-side
application.

---

## 2. Technology stack

### Application
| Concern | Choice |
| --- | --- |
| Language / framework | Ruby 4.0.5, Ruby on Rails 8.1.3 |
| Rendering | Server-rendered ERB + **ViewComponent** + RailsBlocks |
| Interactivity | **Hotwire** — Turbo (Streams, Drive, Frames) + Stimulus |
| CSS | **Tailwind CSS 4** via Vite |
| Bundling | **Vite** (`vite_rails`, `vite-plugin-ruby`, `@tailwindcss/vite`) |
| Auth | **Devise 5** + Google OAuth (`omniauth-google-oauth2`) |
| Forms protection | Cloudflare **Turnstile** |

### Storage & data
| Concern | Choice |
| --- | --- |
| Primary DB | **PostgreSQL** (Active Record) |
| Cache / Queue / Cable | **Solid Cache, Solid Queue, Solid Cable** — all DB-backed (no Redis) |
| File storage | **Active Storage** (local disk in prod; libvips for images) |
| Audio delivery | **Bunny CDN** pull zone with token authentication |
| Media processing | libvips (images), ffmpeg (30s previews/trailers) |

### Integrations
| Concern | Choice |
| --- | --- |
| Payments | **Paddle** (Merchant of Record) via the **Pay** gem (`pay` 12.2, `paddle` 2.10) |
| Calendar | **Google Calendar API** v3 (`google-apis-calendar_v3`, `googleauth`) |
| Transactional mail / newsletter | **Brevo** (HTTP API + SMTP fallback) |
| Error tracking | **Sentry** (`sentry-rails`) |
| Observability | **PgHero** (`/admin/db`), **Mission Control Jobs** (`/admin/jobs`) |

### Tests & ops
| Concern | Choice |
| --- | --- |
| Tests | **RSpec**, Capybara + Selenium, Playwright (`playwright-bdd`) |
| Lint / security | **RuboCop** (rails-omakase), **Brakeman**, **bundler-audit** |
| CI | GitHub Actions |
| Deploy | **Kamal 2** + Docker on a single VPS (OVH), Postgres accessory on same host |
| Edge | Cloudflare (TLS termination, redirects) |

### Client-side JS dependencies (`package.json`)
`@hotwired/stimulus`, `@hotwired/turbo-rails`, `@paddle/paddle-js`, `@rails/actiontext`,
`@rails/activestorage`, `trix`, `cally` (calendar custom elements), `dayjs`,
`embla-carousel`, `lucide` (icons), `photoswipe` (lightbox), `@floating-ui/dom`.

---

## 3. Repository layout

```
app/
  assets/          # images (logo, mascot, avatar), fonts references
  components/      # ViewComponents (design system + shared UI)
  controllers/     # Rails controllers (public, admin, integrations, users, concerns)
  frontend/        # Vite entrypoints, Stimulus controllers, JS libs, CSS, fonts
  helpers/         # view helpers (incl. content_block() accessor)
  jobs/            # Active Job / Solid Queue jobs
  mailers/         # booking, contact, purchase mailers + Brevo delivery
  models/          # ActiveRecord models + concerns + content_block registry
  services/        # plain-Ruby service objects (ApplicationService.call)
  views/           # ERB templates, grouped by controller
config/
  content_blocks.yml   # THE CMS schema (source of truth for editable copy)
  routes.rb            # public locale scope, admin namespace, integrations
  queue.yml, recurring.yml, cable.yml, storage.yml, deploy.yml
  initializers/        # pay webhooks, omniauth, devise, sentry, CSP, pay, pagy
db/
  schema.rb            # PostgreSQL schema (source of truth)
docs/              # ad-hoc audits and content-block docs
bin/               # rails + custom rake/scripts (e.g. content_blocks:sync, admin:promote)
```

---

## 4. Runtime architecture

A single **Puma** web process serves everything. In production (Kamal), the **Solid
Queue supervisor runs inside Puma** (`SOLID_QUEUE_IN_PUMA=true`), so there is no
separate worker container. Postgres runs as a Kamal accessory on the same host; the
Solid Cache/Queue/Cable tables live in the same database.

```
Browser ──(HTTPS, Cloudflare)──> Puma/Rails ──> PostgreSQL
                                   │  ├─ Solid Queue (jobs, in-process)
                                   │  ├─ Solid Cache (Rails.cache)
                                   │  └─ Solid Cable (Turbo Streams over ActionCable)
                                   │
                                   ├─> Paddle (checkout, prices, webhooks)
                                   ├─> Google Calendar API (availability, event mirror)
                                   ├─> Bunny CDN (upload proxy + signed stream URLs)
                                   ├─> Brevo (transactional + newsletter)
                                   └─> Sentry (errors/traces)
```

Key runtime facts for a rewrite:

- **Turbo Streams over Action Cable** (`solid_cable` in prod, `async` in dev) are how
  the "waiting for payment" screens self-update when a webhook lands. The buyer's
  browser subscribes to a stream keyed on the order/booking.
- **Direct-to-cloud uploads** are *not* used for Bunny audio — uploads are **proxied
  through Rails** (chunked) so the Bunny write key never reaches a browser.
- **Active Storage direct upload** IS used for admin media (audio/trailer blobs go
  straight from the browser to the staging service, then are moved to Bunny by a job).

---

## 5. Request / rendering model

1. `ApplicationController` wraps every request in `switch_locale` (around_action) and
   sets Pagy locale + Sentry user.
2. Controllers render **ERB views** built from **ViewComponents**; forms and status
   areas are Turbo Frames/Streams.
3. **Stimulus controllers** attach behaviour to server-rendered DOM (calendars,
   checkout, uploads, accordions, carousel, lightbox, Trix editor).
4. Locale is URL-first: bare paths are Polish, `/en/...` is English. Non-locale-scoped
   routes (Devise, admin, OAuth callback) carry locale via `?locale=` and the session.
5. The public layout emits per-page `title`, `meta description`, `canonical`, Open
   Graph and Schema.org JSON-LD (sitewide `Organization`/`WebSite`, per-article
   `BlogPosting`). Discovery files — `/sitemap.xml`, `/blog/feed.rss`, `/llms.txt`,
   `/llms-full.txt` — are first-party; their *copy* (brand name, default
   description, social link) reads from content blocks (`seo.site.*`), so it is
   owner-editable without a deploy, while the schema structure stays in code.

The frontend JS entry (`app/frontend/entrypoints/application.js`) imports Turbo,
ActiveStorage, the Stimulus controller manifest, page-feature loaders, and Trix CSS.
**Paddle.js and PhotoSwipe load lazily** only when checkout/lightbox is triggered
(privacy requirement).

---

## 6. Domain model

Primary tables (full DDL in `db/schema.rb`). Enum values and statuses are Rails
enums stored as integers.

| Table | Purpose | Key fields |
| --- | --- | --- |
| `users` | Devise accounts + admin flag | `email`, `encrypted_password`, `provider`/`uid` (Google), `first_name`, `last_name`, `avatar_url`, `admin` |
| `products` | Audio catalogue (2 kinds) | `kind` (`audio_process`/`bedtime_story`), `slug`, `translations` jsonb, `paddle_price_id`, `cdn_path`, `preview_cdn_path`, `trailer_cdn_path`, `expected_chapter_count`, `published`, `position`, `length_minutes`, `icon` |
| `audio_chapters` | Ordered chapters of an audioprocess | `product_id`, `position`, `translations`, `cdn_path`, `duration_seconds`, `upload_error` |
| `packages` | Consultation packages | `translations`, `paddle_price_id`, `duration`, `published`, `position` |
| `bookings` | Consultation reservations | `token`, `status` (pending/confirmed/payment_failed/canceled), `starts_at`/`ends_at`, `package_id`, `user_id`, `calendar_event_id`, `paddle_transaction_id`, `legal_snapshot`, `consent_accepted_at`, `calendar_sync_pending` |
| `orders` | Shop purchases (cart frozen at checkout) | `token`, `status` (pending/paid/payment_failed/canceled), `paddle_transaction_id`, `legal_snapshot`, `consent_accepted_at`, `paid_at` |
| `order_items` | Order↔Product join (no quantity) | `order_id`, `product_id`, `paddle_price_id`, `paddle_transaction_item_id`, `refunded_at`, `first_stream_issued_at`, `first_played_at` |
| `booking_changes` | Audit log of admin cancel/reschedule/settlement | `booking_id`, `admin_id`, `kind`, `initiator`, `reason`, `previous_starts_at`, `new_starts_at` |
| `content_blocks` | One row per editable field | `key` (unique), `value_pl`, `value_en`, + Action Text `body_pl`/`body_en`, `image` |
| `content_items` | Repeating collections (FAQ, certs, testimonials) | `collection_key`, `position`, `values` jsonb |
| `consultation_settings` | **Singleton** (id=1) scheduling config | `booking_window_months`, `minimum_notice_hours`, `local_availability` |
| `consultation_weekly_slots` | Recurring weekly availability | `consultation_setting_id`, `weekday`, `minute_of_day` |
| `consultation_slots` | One-off extra slots | `starts_at` (unique) |
| `consultation_blocks` | Time-off / blocked periods | `starts_at`, `ends_at`, `all_day`, `category`, `note` |
| `integrations` | OAuth grants (Google Calendar) | `service_name` (unique), encrypted `access_token`/`refresh_token`, `calendar_id` |
| `testimonial_invitations` | Consent-gated review collection | `token`, `recipient_label`, `status`, `quote`, `author`, `consented_at`, `published_content_item_id` |
| `staged_media_uploads` | Chunked admin upload tracking | `token`, `target_type/id`, `filename`, `byte_size`, `chunk_count` |
| `paddle_adjustments` | Refund records from Paddle | `paddle_id`, `transaction_id`, `customer_id`, `status`, `action`, `payload` |
| `product_slug_histories` | Slug reuse guard | `product_id`, `slug` (unique) |
| `articles` | Blog articles (owner-published long-form) | `slug` (unique), `published`, `published_at`, `translations` jsonb, Action Text `body_pl`/`body_en`, `cover_image` |
| `article_slug_histories` | Slug reuse guard + old-URL redirects | `article_id`, `slug` (unique) |

Supporting tables: `action_text_rich_texts`, Active Storage (`blobs`, `attachments`,
`variant_records`), Pay gem tables (`pay_customers`, `pay_charges`,
`pay_webhooks`, `pay_subscriptions`, `pay_payment_methods`, `pay_merchants`), and
Solid Queue/Cache/Cable tables.

### Non-persisted models
- `Cart` — the visitor's cart is a **set of product ids in the session** (no
  quantities; digital goods are bought once). Resolves current product data on every
  read and filters out `claimed?` (already owned or mid-payment) items.
- `ContactMessage`, `NewsletterSignup` — `ActiveModel` form objects only; they
  validate and go straight to the mailer / Brevo (no stored copy).

### Shared model concerns
- `Purchasable` — shared shape for `Product` and `Package`: bilingual copy
  (`Translatable`), `paddle_price_id`, `position`, `published`, ordered scope.
- `Translatable` — per-locale values in a single jsonb column
  (`field => locale => value`), falling back to Polish.
- `Refundable` — computes `refund_state` from `paddle_adjustments` + transaction
  snapshot (full / partial / pending_approval / rejected / none).

---

## 7. Key flows

### 7.1 Audio purchase (cart → order → stream)

1. Buyer adds a `Product` to the session `Cart` (idempotent toggle, no quantity).
2. Cart view reads prices **from Paddle** (`PaddlePriceCatalogService`) — the app
   stores no amounts. Any line whose price can't be read renders "price
   unavailable"; the total is `nil` if any line has no price.
3. `OrdersController#create` (requires sign-in): builds a `pending` `Order` from the
   cart's **buyable** lines, verifies a refund-policy token + digital-consent flag,
   snapshots them, and builds a Paddle checkout payload (`items` = price ids,
   `customer_id` = the Pay customer, `custom_data = { order_id }`,
   `success_url`/`abandon_url`). On success the cart is cleared; on Paddle failure
   the order is destroyed.
4. The browser opens **Paddle's overlay** (`@paddle/paddle-js`, lazy-loaded). Closing
   it with no payment fires `checkout.closed`; the controller's `abandon` action
   (DELETE) restores the cart lines and deletes the order.
5. **`paddle_billing.transaction.completed`** webhook → `OrderConfirmationService`
   (subscribed in `config/initializers/pay.rb`) → `Order#mark_paid!` (idempotent),
   then the order **broadcasts a Turbo Stream** to the buyer's `orders#show` page.
6. Streaming: the `ProductDelivery` concern (shared by `StoriesController` and
   `AudioProcessesController`) checks paid, non-refunded access
   (`issue_stream` → `current_user.accessible_order_items`), records
   `first_stream_issued_at`, then redirects to a **Bunny signed URL**
   (`BunnySignedUrlService`, 6h TTL). Chapter streams (`stream_chapter`), story
   `stream`, the audio-process `trailer`, and the public `preview` (15-min TTL, no
   ownership check) are analogous.

### 7.2 Consultation booking

1. `BookingsController#index` loads availability via `BookingAvailability` /
   `ConsultationCalendarService`. Free slots are computed from the owner's Google
   Calendar busy periods (`GoogleCalendarService#busy`, which reads events — not
   `freebusy` — so transparent all-day events still block) **plus** local
   availability settings (weekly slots, extra slots, blocks).
2. `BookingsController#create` builds a `pending` `Booking` (email taken from the
   account, never the form), checks the package is priceable, verifies refund-policy
   token + (if <14 days out) early-service consent, then
   `ReserveConsultationService` holds the slot.
3. A Paddle checkout payload is built (`custom_data = { booking_id, booking_token }`),
   and `BookingCalendarService` writes a **holding event** to Google Calendar.
4. `transaction.completed` → `BookingConfirmationService` → `Booking#confirm_payment!`
   (locked, idempotent via unique `paddle_transaction_id`) → Google Calendar event
   updated and status broadcast to the waiting page.
5. Payment failed/canceled → `BookingPaymentFailureService` schedules a grace-period
   release; the slot is only freed after `BookingPaymentCheckService` confirms Paddle
   still reports unpaid.

### 7.3 Abandoned / failed cleanup (recurring)

`config/recurring.yml`:
- `ReleaseAbandonedBookingsJob` and `ReleaseAbandonedOrdersJob` — every 15 min, free
  pending checkouts nobody finished.
- `purge_unattached_blobs` and `PurgeStagedMediaUploadsJob` — daily cleanup of orphan
  uploads.
- `clear_solid_queue_finished_jobs` — hourly housekeeping.

---

## 8. The content-block (CMS) system

`config/content_blocks.yml` **is the schema**. It defines `pages → sections → fields`
with types `plain`, `rich` (Action Text/Trix), and `image`, plus `collection`
(repeating lists of plain fields). Meaning comes from nesting depth; keys are
`page.section.field` (flattened by `ContentBlock::Registry`, never hand-written).

- A rake task (`content_blocks:sync`) creates one `ContentBlock` row per declared
  key, idempotently, on deploy.
- Every field ships a `default` so no section renders blank; `en` defaults fall back
  to `pl`.
- Views access copy through a `content_block("page.section.field")` helper; there is
  no Ruby code naming individual fields.
- `ContentItem` rows back `collection` sections (add/reorder/delete in the panel).
- Admin panel (`/admin/content_blocks`) is generated from the registry (Polish-only,
  one section at a time, PL/EN tabs, Trix for rich fields). `admin_hidden: true`
  keeps a field for later restoration without showing its controls.
- Translations on `Product`/`Package`/`AudioChapter` are *not* content blocks — those
  records carry identity + foreign keys, so they use the `Translatable` jsonb column
  instead.

---

## 9. Integrations in detail

### Paddle (Merchant of Record) — via Pay gem
- **No prices are stored in the app.** `Product`/`Package` hold a `paddle_price_id`;
  `PaddlePriceCatalogService` reads formatted amounts from Paddle.
- Checkout is always Paddle's overlay (`@paddle/paddle-js`), lazy-loaded only when a
  checkout opens.
- Webhooks (`config/initializers/pay.rb`) subscribe to:
  `transaction.completed`, `transaction.payment_failed`, `transaction.canceled`,
  `adjustment.created/updated`. Each handler is **idempotent** (Pay can re-run the
  whole chain).
- `PaddleTransactionService` is the shared, defensive webhook lookup: it resolves the
  order/booking from `custom_data`, verifies the Paddle customer matches the record's
  owner, checks the token and a created-after guard.
- Refunds: `PaddleRefundService` records `paddle_adjustments`; a **full** refund of an
  audio item removes access (`refunded_at`), a partial refund does not.

### Google Calendar
- Owner connects via OAuth (`integrations/google_calendar`); tokens are stored
  encrypted on the `integrations` row. `GOOGLE_CALENDAR_ID` is a fallback only.
- Availability reads events (not freebusy) to catch transparent/all-day blocks.
- Bookings are **mirrored** to the chosen calendar in Polish; sync failures set
  `calendar_sync_pending` and retry (`SyncBookingCalendarJob`).
- Local availability (weekly slots / extra slots / blocks) can be activated
  independently; Google remains a booking copy in that mode.

### Bunny CDN
- Audio lives in a Bunny storage zone fronted by a token-authenticated pull zone.
- Stream routes check entitlement, then redirect to an **HMAC-SHA256 signed URL**
  (`BunnySignedUrlService`), 6h for owned audio, 15-min for public previews.
- Uploads are **proxied by the app** (chunked via `StagedMediaUploadsController`),
  then moved to Bunny by jobs (`ProductAudioUploadJob`, `AudioChapterUploadJob`,
  `ProductTrailerUploadJob`). Previews/trailers are generated with ffmpeg.

### Brevo
- Transactional mail (booking/contact/purchase) via HTTP API (`brevo_api_delivery`)
  with SMTP fallback. Newsletter subscriptions go straight to a Brevo list (double
  opt-in); no local list copy.

### Cloudflare Turnstile
- Protects public forms (contact). Loaded lazily when a visitor interacts with a
  protected form, verified server-side (`TurnstileVerificationService`).

---

## 10. Authentication & authorization

- **Devise** with database auth + **Google OAuth**. One user model, two sign-in
  routes; Google sign-ups have **no password** (surfaces must offer "set a password"
  instead of demanding one). `User#password_required?` excusing only the
  password-less Google case.
- **Authorization is a single `users.admin` boolean.** The entire `/admin` namespace
  (panel, Solid Queue dashboard at `/admin/jobs`, PgHero at `/admin/db`) is gated by
  it. There are no roles beyond admin.
- Admin is granted via `bin/rails 'admin:promote[email]'`.

---

## 11. Localization

- Two locales: `pl` (default) and `en`. Bare paths are Polish; English is the same
  route under `/en`. Non-locale-scoped routes (Devise, admin, OAuth) use
  `?locale=` + session.
- `I18n` fallback to Polish is on, so untranslated content falls back deliberately.
- Editable copy is bilingual per content block; `nav.*` chrome strings live in locale
  files, not content blocks.
- Email + error pages are bilingual. The admin panel and Google Calendar mirror are
  **Polish-only** (staff-facing).

---

## 12. Frontend architecture (rewrite-relevant)

| Piece | Where | Role |
| --- | --- | --- |
| Design tokens | `DESIGN.md` frontmatter + `app/frontend/entrypoints/application.css` | Warm near-black palette, Baloo 2 + Quicksand, dark-only, no light theme |
| ViewComponents | `app/components/*` | `Card`, `Section`, `Container`, `Button`, `Alert`, `Accordion`, `Navbar`, `Sidebar`, `Table`, `Pagination`, `Lightbox`, `Carousel`, `Toast`, `TreeView`, `Forms`, `LoadingIndicator`, `Testimonial` |
| Stimulus controllers | `app/frontend/controllers/*_controller.js` | `paddle`, `consultation_calendar`, `cally`, `playback`, `audio_upload`, `media_upload`, `media_preview`, `package_details`, `lightbox`, `carousel`, `accordion`, `navbar`, `toast`, `turnstile`, `tree_view`, `content_blocks`, `product_slug`, `product_kind`, `chapter_playlist`, `avatar`, `image_fallback`, `copy`, `locale`, `tooltip`, `sidebar`, `flash`, `consultation_block_form`, `package_copy`, `live_preview`, `article_editor`, `cart_focus` |
| JS libs | `app/frontend/lib/` | `paddle.js` (lazy Paddle load), `lightbox_viewer.js`, `page_features.js`, `rich_text_editor.js` |
| Rich text | Trix + `@rails/actiontext` | CMS `rich` fields |

Mapping hints for a React/Next.js rewrite (see §15): each ViewComponent is a strong
candidate for a React component; each Stimulus controller maps to a hook/event
handler or a client component; Turbo Streams (server-push status updates) map to
websockets/SSE or polling; the content-block helper maps to a server-side content
query feeding an editable CMS.

---

## 13. Admin panel (`/admin`)

Polish-only staff UI, all behind `users.admin`. Areas: dashboard, bookings (index/
show + cancel/reschedule/settlement), orders (index/show), content blocks/items,
testimonial invitations (create/approve/decline), packages & products (+ audio
chapters, slug preview), articles (the blog), consultation calendar + settings +
blocks + slots, Paddle price refresh, staged media uploads, Solid Queue
(`/admin/jobs`), PgHero (`/admin/db`).

---

## 14. Privacy & security constraints (binding for any rewrite)

From `PRODUCT.md` — these are product commitments, not preferences:

1. **Passive reading makes no third-party request.** No analytics, tag manager, ad
   pixel, font CDN, consent banner. Fonts/assets are self-hosted. The only exception:
   a hotlinked Google avatar for Google sign-ins.
2. **Paddle.js loads only when checkout opens**; Turnstile loads only on form
   interaction. Any new third-party asset requires an explicit decision.
3. **No prices or money math in the app** — Paddle owns amounts; every commerce
   surface must render a truthful "price unavailable" state.
4. **Audio is streamed, never handed over** — signed URLs only; the Bunny write key
   never reaches the browser.
5. **WCAG 2.1 AA is binding** (EU Accessibility Act) — phone-first, 44px targets,
   visible focus, error recovery.
6. Secrets live in ENV (no Rails encrypted credentials for deployment config);
   `SECRET_KEY_BASE` and all integration keys ship via Kamal secrets.

---

## 15. Notes toward a React/Next.js + separate backend

This is descriptive, not a plan. The current coupling points that most affect a
split:

- **Server-rendered HTML + Turbo is the entire UI contract.** There is no JSON API
  today (only `jbuilder` is installed, unused for the main flows). A Next.js frontend
  implies building an API surface that does not exist yet — controllers currently
  render ERB/Turbo.
- **Turbo Streams carry the payment-status UX.** Order/booking "waiting" pages
  subscribe to a server-pushed stream when the webhook lands. This maps to
  websockets/SSE or client polling against a status endpoint.
- **The cart is session state on the server** (a cookie-backed set of product ids,
  with `claimed?`/`owned?` filtering). A separate frontend needs an explicit
  cart/claim API and the same "already owned / awaiting payment" logic.
- **Prices come from Paddle server-side.** A Next.js client should not call Paddle
  directly for prices or checkout; the backend must remain the source of price
  lookups, checkout payloads, and webhook handling (Paddle/Pay logic is tightly
  coupled to ActiveRecord and Rails notifications).
- **The CMS is Rails-specific** (YAML registry + ActiveRecord + Action Text/Trix +
  a generated admin). A rewrite must preserve `content_blocks.yml` as the schema and
  reproduce the `page.section.field` keying, the default-fallback rule, and the
  owner-editable panel — or replace the whole CMS story deliberately.
- **Integrations are Rails-coupled:** Pay/Paddle webhooks (`ActiveSupport::
  Notifications`), Google Calendar OAuth token storage (encrypted columns), Bunny
  signing (pure Ruby, portable), Brevo (plain HTTP, portable).
- **Auth is Devise + OmniAuth.** The "Google sign-up has no password" invariant and
  single `admin` boolean must be preserved regardless of the auth implementation.
- **Background work is Solid Queue** (DB-backed, no Redis). Jobs encode the
  retry/grace/idempotency semantics for payments and calendar sync; these rules
  survive any queue-system swap.
- **Observability** (Sentry, PgHero, Mission Control Jobs) and **ops** (Kamal/Docker,
  Cloudflare, single VPS + Postgres) are independent of the frontend choice but
  assume a Rails-shaped host.

### Portable vs. Rails-coupled inventory (quick reference)

| Component | Portability for a rewrite |
| --- | --- |
| `ContentBlock::Registry` + `content_blocks.yml` | Schema portable; registry/admin are Rails |
| `Translatable` / `Purchasable` / `Refundable` | Logic portable; tied to AR enums/jsonb |
| `BunnySignedUrlService` | Fully portable (pure HMAC) |
| `BunnyStorageService`, upload jobs | Portability depends on chosen backend/file storage |
| `GoogleCalendarService`, `AuthorizeCalendarService` | Logic portable; OAuth token store is AR |
| `PaddlePriceCatalogService`, `PaddleTransactionService`, webhook wiring | Webhook handling is Rails/Pay-coupled; pricing API portable |
| `SlotComparatorService`, `ConsultationCalendarService` | Portable scheduling logic |
| `Cart` (session) | Session/AR coupled; the *rules* are portable |
| Stimulus controllers / ViewComponents | UI — replaced by React components/hooks |
| `DESIGN.md` tokens | Portable (feed a Tailwind/vanilla-Extract/CSS-vars theme) |
