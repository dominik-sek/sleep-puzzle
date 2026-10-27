# Frontend production-load comparison

Measured 27 October 2026 using production-built assets served by the local Rails test application. Fixtures, integration stubs, page content, CSS, fonts, network settings, and CPU settings were held constant. This is a lab comparison, not live production telemetry.

## Result

The entry JavaScript shrank from **303,223 to 171,476 bytes** (43.4%). Its gzip estimate fell from **84,070 to 44,328 bytes** (47.3%). Home and shop each still request one JavaScript file.

The table counts **all JavaScript requested by the rendered page**, including relevant optional controllers and the admin rich editor. Sizes are decimal kB. Gzip estimates use the same Ruby `Zlib.gzip` settings on both builds; these are not measured compressed transfer sizes from Rails/CDN.

| Page | JS before → after | Gzip estimate before → after | Gzip reduction | JS requests before → after |
| --- | --- | --- | --- | --- |
| Home `/` | 303.2 → 171.5 kB | 84.1 → 44.3 kB | 47.3% | 1 → 1 |
| Shop `/products` | 303.2 → 171.5 kB | 84.1 → 44.3 kB | 47.3% | 1 → 1 |
| Packages `/packages` | 342.0 → 213.7 kB | 98.7 → 60.2 kB | 39.0% | 2 → 3 |
| New admin product `/admin/products/new` | 525.2 → 428.0 kB | 142.3 → 114.3 kB | 19.7% | 3 → 6 |

The admin product fixture had Bunny Storage unconfigured, so its audio field used the manual-path fallback. Rich-text editing was present and fully loaded. Direct-upload support is separately tested with a dynamically inserted upload field.

More capability requests are the deliberate tradeoff on feature-rich pages. Home/shop no longer carry the carousel, tooltip positioning library, admin tools, or Active Storage. Packages fetch only their calendar and details controllers. Admin product editing fetches sidebar, tooltip, kind selection and rich editor code. Imported modules remain cached across Turbo visits in a normal browsing session.

## Browser timings

Three cold-cache samples per page; table values are medians in seconds. Chrome used a 390×844 browser window, a 4× CPU slowdown, 150ms configured network latency, 200,000 bytes/s download and 93,750 bytes/s upload. The Rails test server serves uncompressed JavaScript, so production CDN compression would change the absolute timings.

| Page | DOMContentLoaded before → after | Load event before → after | FCP before → after |
| --- | --- | --- | --- |
| Home | 4.38 → 3.33 | 4.39 → 3.69 | 2.94 → 2.96 |
| Shop | 4.37 → 3.32 | 4.38 → 3.69 | 2.90 → 2.92 |
| Packages | 4.62 → 3.89 | 4.63 → 3.93 | 3.00 → 3.00 |
| Admin product | 3.79 → 2.78 | 3.81 → 3.20 | 2.46 → 2.46 |

Load-event medians improved by approximately 15–16%. **FCP did not materially improve.** Three samples do not establish statistical significance or a field-performance guarantee. LCP, INP and CLS were not evaluated by this harness. A load event does not prove all asynchronous controls are ready; the harness additionally waits for declared Stimulus controllers and the rich-editor custom element before collecting the complete JavaScript resource list.

Raw samples and requested chunk paths are retained in `docs/frontend-load-2026-10-27.json`. Baseline entry: `application-CQTdAcO3.js`; optimized entry: `application-CUXRDTfj.js`.

## Implementation

- `app/frontend/controllers/index.js` eagerly registers the eight small shared navigation/form controllers. Vite exposes other controller modules through lazy imports, matched to their Stimulus identifiers.
- `app/frontend/lib/page_features.js` uses those definitions for initial documents, Turbo visits, frame replacements, stream templates, inserted nodes and changed controller attributes. Incoming Turbo markup waits for the matching imports before rendering. Imports are shared across concurrent preparations.
- Active Storage starts once only when a direct-upload field is present. Rich-editor JavaScript remains conditional; the existing calendar and image-viewer boundaries are preserved.
- No route layout, copy, design token or visual component was changed in this optimization pass.

Browser regressions cover public pages without optional chunks, initial carousel interaction, streamed accordion and editor controls, conditional direct uploads, first admin preview edits on Turbo entry, calendar selection, package dialogs, media, playback and admin navigation. Two existing test assumptions were corrected: calendar geometry checks now select the open calendar dialog, and the refund/cart check waits for the completed add response rather than an already-present navbar link.

## Validation and remaining limits

- Production build, JavaScript syntax checks, Ruby lint and patch whitespace checks passed. The Impeccable detector reported no primary findings; its 10 existing advisories remain.
- The final focused run passed **23/23** browser checks across deferred features, package details, booking and package layouts. Both production-load measurement runs passed their readiness checks.
- A full browser run exercised **117 examples**. One newly added carousel check used an ARIA-label lookup unsupported by the Capybara configuration; it was corrected to use the rendered control's target and passed in the final focused run. A calendar day-click case failed intermittently in the full-suite runs, then passed in focused reruns of the same calendar sequence. The corresponding baseline sequence also passed. This does not establish the cause of the intermittent failure, and a completely green full-suite result is not claimed.
- The real-MP4 playback test was skipped because ffmpeg is not installed. Other media recovery checks ran.

## Reproduce

Use the installed Ruby/Node runtimes and the local test database. Capture the baseline before changing the loader, then repeat the same commands after the change with another `LOAD_LABEL`:

```sh
VITE_RUBY_PUBLIC_OUTPUT_DIR=vite-benchmark bundle exec vite build --mode production
VITE_RUBY_PUBLIC_OUTPUT_DIR=vite-benchmark \
  VITE_RUBY_AUTO_BUILD=false \
  VITE_RUBY_DEV_SERVER_CONNECTION_CHECK=false \
  LOAD_LABEL=after \
  bundle exec rspec script/measure_frontend_load.rb
```

The build goes into ignored `public/vite-benchmark`; measurements go into ignored `tmp/frontend-load-after.json`. The harness uses synthetic transactional fixtures and stubs external prices/calendar reads. Run it separately from other tests to avoid database contention and reduce timing noise. It does not contact the production site or perform purchases.
