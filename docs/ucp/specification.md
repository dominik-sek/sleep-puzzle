# Sleep Puzzle browser checkout

Sleep Puzzle publishes its Universal Commerce Protocol (UCP) business profile at
`https://sleeppuzzle.com/.well-known/ucp`, using protocol version `2026-08-25`.
The canonical profile is the `ucp` object. Top-level `protocol_version`,
`services`, `capabilities`, and `endpoints` also expose discovery information.
See the [UCP specification](https://ucp.dev/specification/overview/).

## Service and capability

`com.sleeppuzzle.shopping` describes the existing browser entry points using a
REST OpenAPI document at `/ucp/services/browser.openapi.json`.
`com.sleeppuzzle.shopping.browser_checkout` is a Sleep Puzzle capability for
handing a purchase to the customer's browser. Its configuration schema is at
`/ucp/schemas/browser-checkout.json`. Both URLs are relative to this origin and
are available without authentication.

The capability's `config` contains absolute HTTPS `catalog`, `checkout`, and
`authentication` URLs, `payment_provider: "paddle"`, and
`requires_authentication: true`.

## Buying digital content

1. Open the `catalog` URL (`/products`) in the customer's browser. Let the customer
   choose published audio content and add it to the cart using the site's forms.
2. Open the `checkout` URL (`/cart`) in the same browser, retaining session cookies.
3. Sign in through `authentication` (`/users/sign_in`) when requested. Email and
   password or interactive Google sign-in are supported; see `/auth.md`.
4. Let the customer review the cart, prices, terms, and digital-content consent.
   Submit the checkout form only with their authorization, using its current
   CSRF and policy tokens. Paddle collects payment details in its browser overlay.
5. Paddle's verified completion webhook grants access to purchased audio in the
   customer's dashboard. Opening the profile, catalog, or cart does not charge
   the customer or grant access to paid content.

These entry points return HTML and use browser sessions. This capability does
not implement `dev.ucp.shopping.checkout`, JSON checkout-session operations,
autonomous charging, or a UCP payment handler. `ucp.payment_handlers` is empty
because Paddle is used through the existing browser flow. Agents must hand
payment and consent to the customer; discovery alone is not payment authorization.
