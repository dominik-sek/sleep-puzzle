# Products shop: scoped audit and changes

15 October 2026. Scope: `/products`, the cart entry, and the handoff to a selected
package on `/packages`. Changes implement the user's requested refinements.

## Implementation integrity: pass

The shop retains its existing audio catalogue, consultation packages, design
tokens and commerce controls. Package previews now say **Zobacz pakiet**; the
destination highlights the selected card with an amber border and **Wybrany
pakiet**. **Zobacz terminy** remains on the package page, where it leads to the
existing calendar or signed-in booking flow.

The returning-buyer sign-in note sits directly below the shop introduction,
before the category links, so purchased recordings are easy to find on arrival.

The selection is a native `:target` state. Shop package links use regular browser
navigation (`data-turbo="false"`) so the browser establishes the fragment target;
Turbo history updates alone did not establish that CSS state in the inspected
browser. The target has a readable name, can receive focus, and clears the sticky
navigation through its existing scroll margin. No selection script or animation
was added. Both new labels are editable content blocks in Polish and English.

## Audit health score

| Dimension | Score | Evidence and limits |
| --- | --- | --- |
| Accessibility | 3/4 | Named native links, H3 package names, focusable destinations, visible focus, and a text cue alongside color. No complete assistive-technology certification performed. |
| Performance | 3/4 | No added dependencies, media or JavaScript; native navigation deliberately reloads the package page. No production timing profile performed. |
| Responsive design | 4/4 | Phone and desktop verification; cart visible beside heading with a target at least 44px in each dimension; selected card below navbar; existing doubled-text regression passes. |
| Theming | 4/4 | Added selection CSS uses the existing accent token; new controls use existing surface, border, type and focus tokens. |
| Implementation integrity | 4/4 | Labels match destinations; existing pricing, availability and cart behavior retained; selection cue names the exact chosen package. |
| **Total** | **18/20** | **Excellent within the checked scope.** |

## Findings addressed

Three P2 findings; no scoped P0 or P1 findings. All three were resolved in this
change. The original symptoms and their impact are recorded below.

1. **[P2] Cart entry below both audio collections.**
   Location: `app/views/products/index.html.erb`, shop header and former delivery
   block. Category: responsive design / information hierarchy. Buyers had to
   browse past the catalogue to find the explicit cart action. Moved it beside
   the heading, preserving the distinct `cart_pill` Turbo stream target and count.
   Related command: `$impeccable layout`.
2. **[P2] Calendar promise led to a package overview with no arrival cue.**
   Location: shop package links, `app/views/packages/index.html.erb`,
   `app/views/packages/_card.html.erb`, and the `.package-overview:target` rules in
   `app/frontend/entrypoints/application.css`. Category: implementation integrity
   / accessibility. Buyers had to identify their choice again, and the CTA
   misrepresented the next screen. Renamed the CTA, preserved its exact package
   fragment, and added a named, focusable target with border and text indication.
   Related commands: `$impeccable clarify`, `$impeccable harden`.
3. **[P2] Format/access facts interrupt catalogue browsing.**
   Location: `app/views/products/index.html.erb`, former delivery block.
   Category: implementation integrity / information hierarchy. This block added
   reading between the audio and consultation choices. Removed it from the shop
   as requested. Product-detail delivery facts remain available.
   Related command: `$impeccable distill`.

## Detector and existing context

The detector found no issues in the changed templates. Scanning the entire
existing stylesheet produced three palette advisories: the legacy white
`div.form-control` background and the two black dialog backdrops. These are
pre-existing rules, not newly added colors; the functional backdrops are not
evidence of selection-style drift. No extra palette change is needed for this
scope. The hook also reported a stale design sidecar; it was left unchanged
because context repair was not requested.

Positive patterns retained: shared price/cart state, unavailable-price behavior,
owner-editable copy, self-hosted fonts, focus styles, and kind-specific audio
collections. The main systemic issue here was the transition between preview
and destination; matching the action label and preserving context resolves it.

## Verification

- 98 request/system examples passed: products, carts, packages, category
  navigation and package details. Coverage includes both locales, doubled text,
  unique cart IDs, owned/pending/unavailable states, selected-card visibility,
  navbar clearance, and dialog focus restoration.
- Local catalogue inspected on desktop and at 390px: first-screen cart,
  package selection, exact target identity and no horizontal overflow.
- Production Vite build passed; diff whitespace check passed.
- System-test captures: `tmp/shop-ux-1440.png`, `tmp/shop-ux-390.png`,
  `tmp/shop-package-selection-1440.png`, `tmp/shop-package-selection-390.png`.
  These captures use synthetic test catalogue entries.

No further scoped fixes are recommended. Future changes can be checked with
`$impeccable audit`, then `$impeccable polish` if findings require refinement.
