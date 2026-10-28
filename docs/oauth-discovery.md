# OAuth / OpenID Connect discovery

The public JSON endpoints `/.well-known/openid-configuration` and
`/.well-known/oauth-authorization-server` mirror Google's discovery document at
<https://accounts.google.com/.well-known/openid-configuration>. Google is the
identity provider used by the existing OmniAuth sign-in flow.

The document includes `issuer`, `authorization_endpoint`, `token_endpoint`,
`jwks_uri`, `grant_types_supported`, and `response_types_supported`, plus Google's
other OIDC capabilities. Metadata is fetched over HTTPS from that fixed URL,
validated, and cached for one hour. Invalid responses and provider outages return
JSON with HTTP 503 and `Cache-Control: no-store`; they are not cached.

## Authentication scope

The issuer remains `https://accounts.google.com`. Sleep Puzzle is an OAuth client,
and this endpoint is a provider metadata mirror. Clients performing strict OIDC
issuer discovery must fetch the canonical document from Google's issuer URL;
Sleep Puzzle must not be configured as an issuer. See
[OIDC discovery validation](https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderConfigurationValidation).

Publishing this metadata does not enable bearer-token access to Sleep Puzzle's
APIs. Private website operations still require the existing Devise session and
applicable authorization and CSRF checks. Google tokens are not accepted as API
credentials. Adding delegated API access requires a separate authorization-server
and resource-server integration, including client registration, consent, scopes,
token audience validation, and user authorization.

## Validation after deployment

```sh
curl -i https://sleeppuzzle.com/.well-known/openid-configuration
curl -i https://sleeppuzzle.com/.well-known/oauth-authorization-server
curl -sS https://isitagentready.com/api/scan \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://sleeppuzzle.com"}'
```

Check `checks.discovery.oauthDiscovery.status` in the scan response. A scanner
pass confirms discovery visibility; it does not prove delegated API access works.
