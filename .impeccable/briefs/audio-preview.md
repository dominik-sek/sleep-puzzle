# Brief: 30-second audio preview on the product page

Status: **confirmed direction, blocked on one dependency decision.** No code written.

## 1. Job and audience

A parent who has reached the shop is being asked to pay for a recording of a voice
they have never heard. PRODUCT.md names the differentiator as Karola herself, and
the shop is the lower rung of the ladder - the thing offered to families who cannot
reach 1:1. Today that rung sells her voice with an emoji.

Visitor mode: **Operate** on the surrounding page, but the preview itself is the one
**Persuade** moment in the shop. Success is a visitor who presses play and then
decides - either way. A preview that converts nobody but stops a refund is still
working.

## 2. Outcome and proof

Primary action: press play, hear 30 seconds, then add to cart or leave.
The proof is the recording itself. Nothing needs to be claimed about it.

## 3. Selected direction (decisions confirmed)

- **Auto-cut.** The preview is generated from the uploaded file, not cut by hand.
  Karola uploads one file per product as she does today and gets a preview for free.
- **30 seconds** from the start of the recording.
- **Product page only.** Not the grid. Eight players on one screen is a different
  page, and the card's job is to get someone to the product page.
- **An owned product goes straight to the full player**, never the preview. Someone
  who has paid should not be offered a sample of what they own.

## 4. Scope and boundaries

In scope: a `preview_cdn_path` beside `cdn_path`; generation inside the existing
`ProductAudioUploadJob`; an unauthenticated `GET /products/:id/preview` that signs
the preview path; a player on `products/show`.

Untouched: `ProductsController#stream` and its ownership gate, the 6-hour TTL on the
full stream, the admin upload form's shape, and the shop grid.

Anti-goals: no waveform visualisation, no autoplay, no "listen to more" upsell, and
no preview on the card.

## 5. States and ranges

- **No preview yet** (older products, or generation failed): the page renders exactly
  as it does today. The preview is additive and never blocks a sale.
- **Generation failed:** the owner sees it in the panel the same way
  `audio_upload_error` already surfaces; the public page simply has no player.
- **Product shorter than 30s:** the preview is the whole file. Acceptable for a
  30-second lullaby; worth a floor if any product is that short.
- **Owned:** full player, no preview.
- **Unpriced:** no preview either - a page that cannot sell should not spend
  bandwidth. (Open: arguable the other way.)

## 6. Interaction and layout

The player sits directly under the price and above the add button - after the reason
to want it, before the ask. Native `<audio controls preload="none">`, matching the
dashboard: no custom transport to build, keyboard and screen-reader behaviour for
free, and `preload="none"` so a page view costs no bandwidth.

It needs a label saying what it is ("Posłuchaj 30 sekund"), as a content block so
Karola owns the words. The emoji panel stays; the preview is what earns the money,
and cover art is a separate decision.

## 7. Constraints and open decisions

**BLOCKING - a new system dependency.** Auto-cut needs `ffmpeg`, which is not
installed and has no Ruby equivalent here. Adding it means:
  - `brew install ffmpeg` locally,
  - two `apt-get install` lines in the Dockerfile (build and runtime stages),
  - and it ships to the Kamal VPS and the Render staging service.

This is the same shape as the existing `libvips` dependency, which the README
already documents as required - so it is a known pattern in this project, not a new
kind of risk. But it is an infrastructure change with deploy consequences and it
should be an explicit decision, not a side effect of a design task.

Rejected alternatives, with reasons:
  - **Byte-range of the full file.** Bunny's token auth signs the *path*, not the
    range, so any signed preview URL fetches the entire recording. It leaks the
    product. Disqualifying.
  - **App-proxied truncation.** Avoids the leak but puts audio bandwidth on the Rails
    box, abandons the CDN, and cannot map bytes to seconds reliably across formats.
  - **Client-side stop at 30s.** The full URL sits in the DOM. Disqualifying.

Other open decisions a builder must not invent:
  - Whether the preview is regenerated when a file is replaced (assume yes).
  - Preview TTL. The full stream uses 6 hours for pause-and-resume; a preview needs
    minutes, and a short TTL limits scraping.
  - Whether an unpriced product still previews.
