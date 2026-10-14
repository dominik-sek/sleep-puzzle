# Audio catalogue media — polish, 14 October 2026

The program collection (`/audio-processes`) and grouped shop (`/products`) keep concise shared
cards. Native players live on individual `/products/:id` pages. On phones the
identity, purchase state and delivery facts precede supporting media; desktop
places the introduction beside the offer. No player autoplays or preloads video
or audio, and passive reading never fetches the CDN film.

## Trailer posters

`ProductTrailerUploadJob` extracts a JPEG still from the real transcoded film
before purging the upload. The poster stays in first-party Active Storage and is
served through its proxy route. Its metadata records the trailer path: replacing
that path cannot display the previous film's poster. Poster extraction failure
does not reject a successful video upload. Invalid replacement videos retain the
existing trailer and its poster.

Existing trailers can use the same extractor without re-uploading a film. Supply
the actual original MP4 downloaded from the product's configured storage:

```sh
bin/rails 'products:trailer_poster[2,/absolute/path/to/original-trailer.mp4]'
```

This command has been run for product 2 in the local development database. Its
poster is attached data, not a checked-in asset; existing records on another
environment need the same backfill or a normal trailer replacement. No database
migration or new system dependency is needed.

## Playback recovery

Trailer and story sample players share an error message and a keyboard-operable,
44px retry button. Both messages are editable in the shop product CMS fields
(`media_error`, `media_retry`), with PL and EN defaults. Native controls remain
available without JavaScript.

## External delivery issue found

Product 2's `/audioprocesy/film-mniejszy-plik-54ad9c01.mp4` exists in the configured
Bunny storage zone (22,140,025 bytes; 1280×720; about 94 seconds). Both HEAD and
byte-range GET through the configured pull-zone URL return HTTP 404. The response
is a Rails “The page you were looking for doesn't exist” document. A pull-zone
origin pointing at the application rather than the media storage is a likely
explanation, not a verified configuration finding. No external configuration was
changed. Correct the pull-zone origin/path and verify a signed range request
returns the MP4 before treating live playback as ready.

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
