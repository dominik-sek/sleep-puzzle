# `/audioproces` hardening — 13 October 2026

Completed the two requested P1 fixes from the audit: chapter semantics and program completeness before a new purchase is offered.

## Result

- The program section has valid HTML, a real H2, and `aria-labelledby` referencing that heading's unique product-based ID. Parsed-response tests cover Polish and English.
- Audioprocesses now have an owner-set `expected_chapter_count`. A program is complete only when this is positive, matches the total number of chapters, and every chapter has a ready recording.
- Existing programs are deliberately not backfilled from upload counts. The migration leaves the field empty, so an incomplete legacy offer cannot silently become confirmed.
- Published programs remain available to preview. The landing page shows editable Polish/English unavailable copy and suppresses the price/purchase action until the program is complete. Shared purchase controls also enforce the gate on individual product pages and shop cards.
- Direct cart-add requests refuse incomplete programs. Cart resolution rechecks current completeness before totals and checkout are created, protecting older session carts.
- Existing ownership and pending-payment branches run before the new-sales gate. Existing chapter-stream access was preserved and tested.
- The owner can edit the full count in the product form, with a linked label/hint and server-side validation. Bedtime stories do not require it. Chapter associations are preloaded on the affected catalogue/cart paths.

## Owner workflow and deployment

1. Deploy with `bin/rails db:migrate`. The additive migration has already been applied to the local development database; no production deployment was performed.
2. Edit each audioprocess in the admin panel. Set **Liczba nagrań w pełnym programie** to the total promised in the offer, including any promised bonuses. This declaration must match the real program; it is not inferred from marketing text.
3. Add/upload all those chapters. New sales become available only when the exact declared count is present and every chapter is ready, the product is published, and a current Paddle price exists.
4. If the field is cleared, a chapter is missing its recording, or the chapter count differs, new sales pause automatically. Current uploaded previews and existing purchased access are retained.

The local program still has just one chapter and an empty declared count. It correctly remains unavailable for new purchases. This change does not fabricate missing recordings or rewrite the owner's factual offer.

## Validation

- **142 examples, 0 failures:** Product/Cart models; audio landing, cart, orders, and admin-product requests.
- **55 examples, 0 failures:** Product pages, chapter-stream requests, AudioChapter model/admin/upload flow, and the existing audio-process migration regression.
- **7 application/migration Ruby files inspected, no RuboCop offenses.** Invoked the local RuboCop CLI directly to avoid interfering with the existing lint server.
- **Vite production build passed.** The previously audited shared-bundle warning remains; bundle optimization was outside this request.
- **`git diff --check` passed.**
- **Impeccable detector:** only the previously verified advisory for the existing aria-hidden 110px emoji; no new actionable finding.
- **Browser:** verified at 1440×900 and 390×844. Both widths fit without horizontal overflow, expose the correct program heading, and offer no purchase action for the local incomplete program. The mobile unavailable message wraps within the 350px content column. Viewport overrides were reset.

The existing test database had incompatible table permissions. Tests ran in a separate local database created for this task with the current application schema, omitting only the optional `pg_stat_statements` extension because the role cannot install it. Application tables, migrations, model rules, and request behavior were unchanged for the test run. No database permissions were changed. The temporary test database was removed after verification.

## Evidence

![Desktop: unavailable purchase state and restored program heading](/Users/dominiksek/RubymineProjects/sleep-puzzle/.impeccable/harden/evidence/2026-10-13__audioproces-desktop.jpg)

![Phone: unavailable message fits within the content column](/Users/dominiksek/RubymineProjects/sleep-puzzle/.impeccable/harden/evidence/2026-10-13__audioproces-mobile.jpg)

Other findings from the original audit—cart focus continuity, general price-outage access, trailer recovery/captions, and bundle size—were not part of this request. The next visual finishing step is `$impeccable polish /audioproces`.
