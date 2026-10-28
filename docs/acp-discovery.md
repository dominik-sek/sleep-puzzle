# ACP discovery

`GET /.well-known/acp.json` publishes unauthenticated JSON independently of locale,
browser restrictions, and Markdown negotiation. Configured responses return HTTP
200 and are publicly cacheable for one hour. HEAD is also supported.

## Configuration prerequisite

The application currently uses browser-based Paddle checkout. It does not implement
ACP's `/checkout_sessions` API. The discovery endpoint requires details of an actual
ACP implementation before advertising support. Without valid configuration it
returns HTTP 503 with `Cache-Control: no-store`.

Set these environment variables in the deployed application:

| Variable | Value |
| --- | --- |
| `ACP_API_BASE_URL` | Absolute HTTP(S) base URL of the actual ACP API |
| `ACP_PROTOCOL_VERSION` | Supported ACP version, in `YYYY-MM-DD` form |
| `ACP_SERVICES` | Comma-separated implemented services: `checkout`, `orders`, `delegate_payment`, `carts` |
| `ACP_TRANSPORTS` | Comma-separated supported transports: `rest`, `mcp`; defaults to `rest` |

Configure only services and transports the API implements. These values must reach
the running container; setting them only in a local `.env` does not configure
production. With Kamal, add the confirmed values to `env.clear` in
`config/deploy.yml`. The base URL is explicit so proxy and request host headers
cannot change the advertised API destination.

The discovery metadata declares one supported version. It does not create ACP
checkout, order, cart, or payment APIs.

## Validation after configuration and deployment

```sh
curl -i https://sleeppuzzle.com/.well-known/acp.json
curl -sS https://isitagentready.com/api/scan \
  -H 'Content-Type: application/json' \
  --data '{"url":"https://sleeppuzzle.com"}'
```

Confirm HTTP 200 and JSON for discovery, then check that
`checks.commerce.acp.status` is `"pass"` in the scanner response. A passing discovery
check validates the document; it does not prove the advertised API's conformance.

Reference: [ACP discovery specification](https://github.com/agentic-commerce-protocol/agentic-commerce-protocol/blob/main/rfcs/rfc.discovery.md).
