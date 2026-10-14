# Products and stories: implementation verification

14 October 2026. Implemented locally against the approved
`docs/products-and-stories-plan.md` brief.

## Result

- `/audio-processes`, `/stories` and `/testimonials/:token` are the public
  English-named routes in both languages. The existing program and testimonial
  helper names remain. Polish route aliases and redirects are absent.
- `/stories` lists every published bedtime story in catalogue order, with
  editable introduction and empty state, optional duration and native samples.
  The shop remains the mixed catalogue with English section fragments and
  outward collection links. Access facts and account/cart utilities sit between
  audio offers and consultations.
- Product detail URLs remain `/products/:id`. Return links and up to three
  related products follow the product kind. A related section is absent when
  there are no other published products of that kind.
- Story cards and detail pages share the sample partial and existing signed
  preview endpoint. Starting another preview pauses the previous player without
  resetting its position. Navigation and Turbo caching stop playback; history
  restoration does not start it. Cart streams retain the player and keyboard focus.
- Price, cart, owned and pending-payment states use the shared commerce
  components. Missing prices suppress new purchase actions while existing
  account access remains available. Media failures have local status and retry.
- New CMS fields cover collection copy, collection links, category returns and
  related headings. Retired generic return/related fields remain stored but are
  hidden in the editor. No new database migration or product publication is needed.

## Automated verification

Tests used a separate local PostgreSQL test database, since the application's
configured database role could not prepare its test schema. Application database
permissions, environment files and business records were not changed.

| Check | Result |
| --- | --- |
| All request and helper specs, related system specs, and temporary visual capture | 710 examples, 0 failures, 1 existing pending example |
| Confirmation after the final shop layout adjustment | 119 examples, 0 failures |
| RuboCop on 19 affected Ruby files | No offenses |
| Production Vite build | Passed, including the final layout adjustment |
| JavaScript syntax check | Passed |
| Brakeman | 0 errors, 0 security warnings |
| `git diff --check` | Passed |

The pending example is the pre-existing empty `BookingsHelper` spec. The main
regression run covered 622 request examples, 40 helper examples, 47 system
examples and one temporary visual capture. It included route removal,
testimonial validation/submission, CMS editing and fallback, ordering and
publication, zero/one/two/many stories, all commerce states, and both locales.

Playback tests serve a real generated 30-second PCM WAV locally. They verify
deferred media requests, one active sample, retained position and player identity
through cart updates, keyboard focus, failure/retry, and navigation/history.
Program trailers and paid playback retain their existing endpoint coverage.

## Impeccable audit

**Implementation integrity: pass.** Collections, shared details, commerce and
media use the existing product model and reusable components. No second pricing,
ownership or cart implementation was introduced.

| Dimension | Score | Evidence and limits |
| --- | --- | --- |
| Accessibility | 3/4 | Named native controls, heading hierarchy, keyboard cart focus and local live status tested. Production audio/text alternatives and a full assistive-technology audit were not supplied. |
| Performance | 3/4 | Media remains deferred until interaction; no new external assets or dependencies. Production performance was not profiled. |
| Responsive design | 4/4 | 320px, 390px and 1440px scenarios, long names and 200% text; no horizontal overflow. Local section targets remain below the sticky navbar and receive focus. |
| Theming | 4/4 | Existing warm dark tokens, self-hosted fonts and control patterns preserved. |
| Implementation integrity | 4/4 | Direct canonical routes, category continuity and truthful states verified. |
| **Total** | **18/20** | **Excellent within the inspected scope.** |

No new actionable P0/P1/P2/P3 findings remain. The detector returned an existing
advisory for the `text-[110px]` decorative product icon in the detail template.
It sizes the inherited decorative mark, rather than reading text, and was retained
under the brief's instruction to preserve the established visual world. The final
shop layout scan returned `[]`.

Two visual inspection rounds covered phone/desktop shop and stories views and
the English empty collection. The final first-card positions were approximately
523px for the shop and 266px for stories at 390 × 844. Shop category choices now
follow the introduction directly, with the first purchase action visible in the
opening viewport for the supplied fixture. Layout uses natural wrapping and the
existing small-collection caps.

Screenshots and test logs are local QA artifacts under
`/private/tmp/sleep-puzzle-stories-qa` and
`/private/tmp/sleep-puzzle-stories-*.log`. Their product names, audio and Paddle
prices are test fixtures, not published offers. Existing historical audits remain
unchanged and continue to describe their earlier baseline.

## Change preservation and release

A content-hash snapshot of 779 existing files was captured before implementation.
The final comparison found no missing baseline files and only plan-related edits.
Pre-existing product/media hardening, migrations, design context, navbar behavior,
toast fixes and historical audit changes were preserved. Within shared files,
only the relevant route, collection, media, commerce or navigation fragments were
updated. No reset, checkout, database migration or publication of fixture products
was performed.

At release, run `bin/rails content_blocks:sync` to create rows for the new declared
fields. The views and editor already support schema defaults before that sync.
The owner's real story catalogue and supplied media remain the source of truth.
