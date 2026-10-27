# Blog & SEO/AI discovery — plan

> Status: **implemented**. This document records the design and the decisions
> behind the blog feature, and maps the resulting code so it can be found and
> extended without re-deriving it. For the surrounding context see
> [`ARCHITECTURE.md`](../ARCHITECTURE.md), [`PRODUCT.md`](../PRODUCT.md),
> [`DESIGN.md`](../DESIGN.md) and the content-block schema in
> [`config/content_blocks.yml`](../config/content_blocks.yml).

## Purpose

The owner (Karola) needed a place to publish longer-form articles, for two
reasons that drove the whole design:

1. **Traditional SEO** — crawlable article pages that rank and earn links.
2. **SEO for AI chats** — make the same content discoverable and readable by
   LLM/answer-engine crawlers (GPTBot, PerplexityBot, ClaudeBot, Google AI
   Overviews).

Everything is served **first-party** from the existing Rails monolith, so the
site's binding privacy commitment — a passive reader makes **no third-party
request** — is untouched. Crawling bots read our files; they load nothing into a
visitor's browser.

## Decisions

| Decision | Choice |
| --- | --- |
| Data model | A dedicated `Article` model (`Translatable` jsonb + Action Text + slug history), not a content-block collection. Articles have identity (slug, date, published state) and long bilingual bodies. |
| Language | Bilingual, Polish fallback — like every other surface. |
| Authoring | Trix (Action Text); plain text for AI surfaces is derived via `to_plain_text` at render time (no new editor, no new dependency). |
| Home page | A latest-articles strip **is** included (reverses the old "blog teaser" entry in `PRODUCT.md`). |
| AI/SEO scope | Full set in one pass: meta + JSON-LD + sitemap + RSS + `llms.txt`/`llms-full.txt` + `robots.txt`. |
| Owner-editable SEO | Copy (brand name, default description, social link) lives in content blocks; **structure** (schema, sitemap URL set) stays in code. |

## What "SEO for AI chats" maps to here

| Surface | Role |
| --- | --- |
| `llms.txt` + `llms-full.txt` | Curated index + full article text for LLM crawlers (llmstxt.org convention, found at `/llms.txt`). |
| JSON-LD | `Organization`/`WebSite` sitewide; `BlogPosting` per article (headline, dates, image, author, language). |
| `sitemap.xml` | Articles + static pages, both languages, with hreflang alternates and `lastmod`. |
| RSS (`/blog/feed.rss`) | Discovery + syndication; some AI agents ingest feeds. |
| Meta description, canonical, Open Graph/Twitter | Snippets, link previews, cleaner AI summaries. |
| Semantic HTML | Server-rendered `<article>`, single `<h1>`, `<time datetime>`, real headings — crawlable with no JS. |
| `robots.txt` | Points at the sitemap; allows all crawlers (the point of the feature). |

## Data model

`articles` (see `db/schema.rb`):

- `slug` — unique, indexed, generated from the Polish title with a collision
  suffix (`ArticleSlug`), reuse-guarded by `ArticleSlugHistory`.
- `published` — boolean; unpublished is a draft (panel-only).
- `published_at` — set on first publish, editable for backdating/scheduling;
  drives ordering.
- `translations` — jsonb via `Translatable`: `title`, `excerpt`, `meta_title`,
  `meta_description`.
- `body_pl` / `body_en` — Action Text (Trix), the long-form body.
- `cover_image` — Active Storage (`has_one_attached`).

`article_slug_histories` — one row per slug ever used, unique on `slug`. It both
prevents a renamed article's old address from being claimed and powers **301
redirects** from old slugs to the current one (mirrors product slugs).

Ordering is `published_at DESC` (fallback `created_at`), not a manual `position`.

## Public surface

- Routes (inside the existing locale scope): `GET /blog`, `GET /blog/:slug`,
  `GET /blog/feed.rss` — and the `/en/…` equivalents.
- `ArticlesController#index` — paginated (Pagy), `Article.published.newest`.
- `ArticlesController#show` — `published` scope; resolves old slugs via
  `slug_histories` and 301-redirects to the current slug.
- Views: card grid on the index (`articles/_article`), a reading layout on the
  show page (cover, `<time datetime>`, reading time, `trix-copy` body, and an
  offer cross-link for internal linking).
- Nav and footer link the blog; the home page shows the newest three articles.

## Admin surface

`Admin::ArticlesController` (`/admin/articles`) mirrors the catalogue CRUD,
reusing `admin/shared/_translated_input`, `admin/shared/_form_errors`, `Table`
and `Pagination`. Fields: title (PL/EN), slug (blank = auto-generate), excerpt,
body (Trix per locale), cover image, published + `published_at`, and SEO
overrides (`meta_title`, `meta_description`). A "Blog" entry was added to the
admin sidebar.

## SEO / AI layer

- `SeoHelper` — `meta_description`, `brand_name`, `canonical_url`, `og_image_url`,
  `json_ld`, `site_json_ld`, `article_json_ld`. JSON-LD is rendered through
  `json_escape` so owner-authored copy cannot break out of the `<script>`.
- `SitemapController` + `sitemap/index.xml.erb` → `/sitemap.xml`.
- `LlmsController` + `llms/index.text.erb` + `llms/full.text.erb` →
  `/llms.txt` and `/llms-full.txt`.
- `ArticlesController#feed` + `articles/feed.rss.erb` → `/blog/feed.rss`.
- `public/robots.txt` — allows all crawlers and points at the sitemap.

### Editable copy vs. fixed structure

The **copy** emitted by these surfaces is owner-editable in the content panel:

- Per-article SEO: `meta_title` / `meta_description` on the article form.
- Site-wide SEO: the `seo.site.*` content blocks (`brand_name`,
  `meta_description`, `instagram`).

The **structure** (schema.org `@type` values, sitemap URL set, robots.txt
directives) stays in code — a typo there silently breaks rich results, which the
non-technical owner should not be able to do.

## Content blocks added

- `blog.index.*` — `title`, `subtitle`, `empty`, `offer_title`, `offer_body`,
  `offer_link` (blog index and the article-page CTA).
- `home.blog.*` — `title`, `subtitle`, `link` (home strip).
- `seo.site.*` — `brand_name`, `meta_description`, `instagram`.

These ship with defaults so nothing renders blank; `content_blocks:sync` creates
the rows on deploy.

## File manifest

- `db/migrate/20261027090000_create_articles.rb`
- `app/models/article.rb`, `app/models/article_slug_history.rb`
- `app/services/article_slug.rb`
- `app/controllers/articles_controller.rb`
- `app/controllers/admin/articles_controller.rb`
- `app/controllers/sitemap_controller.rb`, `app/controllers/llms_controller.rb`
- `app/helpers/seo_helper.rb`
- `app/views/articles/*`, `app/views/admin/articles/*`
- `app/views/sitemap/index.xml.erb`, `app/views/llms/*`
- `config/routes.rb` (public + admin + discovery routes)
- `config/content_blocks.yml` (blog + home.blog + seo sections)
- `config/locales/pl.yml`, `config/locales/en.yml` (`blog.*` keys)
- `public/robots.txt`

## Verification

| Check | Result |
| --- | --- |
| `db:migrate` | clean |
| `zeitwerk:check` | all good |
| New + affected specs | 53 examples, 0 failures |
| Full non-system suite | 1142 examples, 0 failures (7 pre-existing pending) |
| RuboCop | no offenses |
| Brakeman | 0 warnings |

Tests added: `spec/models/article_spec.rb`, `spec/requests/articles_spec.rb`,
`spec/requests/seo_spec.rb`, `spec/requests/admin/articles_spec.rb`, plus the
`navigation_helper_spec` and `home_spec` updates.
