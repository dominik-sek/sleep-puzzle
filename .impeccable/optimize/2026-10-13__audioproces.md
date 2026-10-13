# /audioproces optimization — 13 October 2026

The largest confirmed loading cost was the shared JavaScript bundle. The audio landing page downloaded Trix, Action Text, Cally, and calendar date handling despite containing neither an editor nor a calendar.

## Measurements

Production builds from the same working tree, before and after this optimization. The baseline includes the preceding chapter-markup and purchase-readiness repairs.

| Initial JavaScript | Before | After | Reduction |
| --- | ---: | ---: | ---: |
| Minified bytes | 545,653 | 294,609 | 46.0% |
| Gzip bytes, Node `gzipSync` with default options for both files | 151,202 | 82,162 | 45.7% |
| Vite build gzip estimate | 152.45 kB | 82.84 kB | 45.7% |

Baseline: `application-CbJDn2cv.js`. Result: `application-DLtVfhdB.js`.

The result's manifest has no static JavaScript imports. The table therefore measures the entire initial JavaScript dependency closure, rather than merely the entry file after moving its dependencies into eagerly loaded chunks.

Separate modules now contain the editor (212.73 kB minified) and calendar (38.82 kB minified). Their imports are triggered by the matching page elements. A live asset inventory on `/audioproces` confirmed neither feature was requested. PhotoSwipe and Action Cable were already deferred before this change.

CSS and font assets are unchanged. Trix's stylesheet remains shared because its `.trix-content` rules also style published copy and attachments. This pass makes no claim about field LCP, INP, CLS, or elapsed load time: no representative device/network or deployed field measurement was taken.

## Behavior

- Navigation and shared form controllers remain immediately available.
- The Cally custom elements load alongside their controller and date library.
- Turbo page and frame rendering waits for required features before replacement.
- Initial HTML, inserted stream content, and changed controller attributes are detected.
- In-flight imports are shared. A rejected import is reported and can retry on a subsequent visit.
- Action Text's attachment listeners install before Trix upgrades editors. Existing direct-upload form listeners still start once in the shared entrypoint.
- Chapter markup and purchase-readiness guards from the preceding hardening pass are retained.

## Verification

`vite build` succeeded; the previous oversized-entry warning is gone. Vite's existing HMR configuration deprecation remains unrelated to this change.

14 system examples passed across deferred features, package booking, content editing, chapter playback, avatar persistence, and native disclosures. New coverage verifies:

- No editor/calendar custom elements or resource requests on the audio landing page, followed by a working cart Turbo Stream toggle.
- Calendar initialization after a Turbo visit and the first date selection.
- Deferred rich editing after navigating from a plain-text CMS section, including saving typed text.
- Editor upgrade and hidden-field synchronization after a Turbo Stream insertion.

The booking test now freezes its time before the first morning appointment; its prior `08:15` assertion depended on the wall clock.

Ruby lint for changed system specs and `git diff --check` passed. Impeccable's detector reported no findings in the changed frontend files.

Live browser checks: desktop and 390px phone composition, no horizontal overflow, retained H2 chapter heading and rich text, keyboard mobile menu activation/focus, and Turbo navigation. No browser errors or warnings were observed. The live package calendar currently displays its existing availability-service fallback; functional calendar checks used the isolated test suite's service stub.

Evidence: [desktop](evidence/audioproces-desktop.jpg), [phone](evidence/audioproces-mobile.jpg).

Changes are local and uncommitted. For the next visual refinement pass, use `$impeccable polish /audioproces`; deployed field performance should be measured separately.
