# Audio catalogue media — polish, 14 October 2026

The program collection (`/audio-processes`) and grouped shop (`/products`) keep concise shared
cards. Native players live on individual `/products/:id` pages. On phones the
identity, purchase state and delivery facts precede supporting media; desktop
places the introduction beside the offer. No player autoplays or preloads video
or audio, and passive reading never fetches the CDN film.

## Trailer posters

`ProductTrailerUploadJob` extracts a JPEG still and measures the real transcoded
film before purging the upload. The poster stays in first-party Active Storage and
is served through its proxy route. Its metadata records the trailer path and
duration: replacing that path cannot display the previous film's poster or length.
The trailer partial renders the duration below the player before Play, while
`preload="none"` keeps passive reading from fetching the CDN film. Poster extraction failure
does not reject a successful video upload. Invalid replacement videos retain the
existing trailer and its poster.

Existing trailers can use the same extractor without re-uploading a film. By
default it reads the product's signed Bunny URL; an original local MP4 can also be
supplied:

```sh
bin/rails 'products:trailer_poster[2]'
bin/rails 'products:trailer_poster[2,/absolute/path/to/original-trailer.mp4]'
```

Product 2's poster and duration (94 seconds) were backfilled in local development
and production on 15 October 2026. The production poster is immediately visible;
the duration caption and automatic duration extraction require deploying this
application change. Posters are attached data, not checked-in assets; other
existing records need the same backfill or a normal trailer replacement. No
database migration or new system dependency is needed.

## Playback recovery

Trailer and story sample players share an error message and a keyboard-operable,
44px retry button. Both messages are editable in the shop product CMS fields
(`media_error`, `media_retry`), with PL and EN defaults. Native controls remain
available without JavaScript.

## External delivery issue resolved — 15 October 2026

Product 2's `/audioprocesy/film-mniejszy-plik-54ad9c01.mp4` exists in the configured
Bunny storage zone (22,140,025 bytes; 1280×720; about 94 seconds). The pull zone
`sleep-puzzle-pz` (6723587) had its Origin URL set to `https://sleeppuzzle.com`,
so CDN requests fetched a Rails 404 page instead of the uploaded file.

Changed the pull zone's origin type to Storage Zone, selected
`sleep-puzzle-audio-zone` (1960752), and purged the cached responses. Signed
byte-range requests now return HTTP 206 with `Content-Type: video/mp4` and the
expected file size. Unsigned requests still return HTTP 403.

The page's `/audioprocesses/:slug/trailer` source is intentional: the app redirects
to a freshly signed Bunny URL when playback starts. Both local development and
production use the repaired pull zone; no application deployment is required.

## Verification

Inspected the real collection, grouped shop and product 2 at 1440px and 390px:
shared names, prices, sales pause, facts, disclosure and navigation agree; no
horizontal overflow. Existing responsive browser checks additionally cover 320px,
844px, 200% text, long names, and story/trailer/fallback variants. The detail page
now displays a still of Karola from the actual introduction. The real CDN failure
also visibly exposes the recovery action.

39 focused request, upload-job and browser examples passed across the catalogue,
details, poster delivery, native MP4 playback, privacy and keyboard recovery.
Ruby lint, JavaScript syntax and source whitespace checks pass. The design scan
found zero anti-patterns; its sole advisory is the existing, hidden decorative
110px emoji in the no-media fallback. Paid checkout and production configuration
were not changed or exercised.


## Story collection samples (14 October 2026)

`/stories` and `/en/stories` use the shared product cards with optional native
30-second samples. The shop and program collection retain concise cards without
players. Story detail pages use the same sample partial. Story duration is shown
when the product supplies it; there is no empty media slot.

The shared media controller pauses the previous preview when another starts,
without resetting its position, and stops playback on Turbo navigation, caching,
disconnection and browser page exit. Restoring the page never starts playback.
Cart streams replace only the commerce regions and leave the media node intact.
Failure and retry remain local to the recording.

Prices, owned/pending states and cart actions share the existing commerce partials.
An unavailable price prevents new purchase actions while account access remains
available. Full recordings continue to require the existing ownership checks.
