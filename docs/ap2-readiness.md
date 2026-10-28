# AP2 merchant integration

Status: not implemented. The A2A Resource Guide is read-only; its Agent Card
must not advertise support for executing payments yet.

Sleep Puzzle is a commerce site: it sells audio programmes and consultations.
The audit's “not a commerce site” classification is incorrect. Its separate
finding that AP2 payments are unavailable is accurate for the current code.

## Current integration boundary

- `config/agent_card.json` describes public resource discovery.
- `app/controllers/a2a_controller.rb` returns a public resource directory.
- `app/controllers/orders_controller.rb` requires a signed-in customer and
  prepares a browser checkout with Paddle, including digital-content consent.
- `app/services/paddle_transaction_service.rb` matches payment webhooks to
  the expected customer and purchase. It does not verify AP2 mandates.

Adding metadata alone would not allow an agent to pay on a user's behalf.

## Requested discovery metadata

Once a merchant agent implements the payment flow, merge this entry into its
Agent Card's `capabilities.extensions` array, preserving other capabilities:

```json
{
  "uri": "https://github.com/google-agentic-commerce/AP2/tree/v0.1.0",
  "description": "AP2 merchant payments using cryptographically signed mandates.",
  "required": true,
  "params": {
    "roles": ["merchant"]
  }
}
```

This is a proposed extension entry, not a complete Agent Card or an active
capability declaration. The requested URI deliberately targets AP2 v0.1.0;
use that version's mandate models throughout the integration.

## Work needed before advertising support

Choose whether to implement the merchant service here or connect an existing
AP2 merchant agent. An existing service needs a public A2A endpoint and an
authentication contract. A new service needs a credential-provider and payment
processor integration that supports the chosen AP2 flow; the current browser
checkout does not establish that support.

The merchant flow needs to authenticate delegated requests, bind purchases and
consent to the correct customer, issue and persist signed cart mandates, verify
mandate signatures and their trust chain, check expiry and purchase constraints,
and prevent replay or duplicate charges. Keep fulfillment tied to confirmed
payment and preserve the existing order and consultation ownership checks.

Before release, exercise a complete sandbox payment and verify that invalid,
expired, replayed, or mismatched mandates cause no charge or fulfillment.
Verify A2A extension negotiation, including rejection of requests without the
required extension, then add the extension to the implementing agent's card.

## References

- [AP2 documentation](https://ap2-protocol.org/)
- [Requested AP2 v0.1.0 specification](https://github.com/google-agentic-commerce/AP2/blob/v0.1.0/docs/specification.md)
- [A2A specification](https://a2a-protocol.org/latest/specification/)
