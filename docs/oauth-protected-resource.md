# OAuth Protected Resource Metadata

The standalone Cloudflare Worker in `cloudflare/oauth-protected-resource/` serves
`https://sleeppuzzle.com/.well-known/oauth-protected-resource` as public JSON
according to [RFC 9728](https://www.rfc-editor.org/rfc/rfc9728). Its route covers
only metadata discovery; Rails and its Devise/Google sign-in continue to serve
the rest of the site.

## Cloudflare Access prerequisite

Use an existing Access application for the intended protected resource, with
[Managed OAuth](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/managed-oauth/)
enabled. Access requires an identity provider and explicit access policies.
Publishing metadata alone does not enable OAuth or make an Access identity a
Rails user. Do not put the public storefront behind a new Access login merely to
pass a discovery scan.

Fetch the application's `/.well-known/oauth-authorization-server` document and
copy its exact `issuer` into `ACCESS_ISSUER`. An OAuth issuer may include a path;
do not infer it from a team name or use a login/token/metadata endpoint instead.
For an application protecting the site origin, start with:

```sh
curl --fail --silent --show-error \
  https://sleeppuzzle.com/.well-known/oauth-authorization-server
```

The configured resource is `https://sleeppuzzle.com`. If Access protects a
different resource (for example, a dedicated API hostname or path), align the
resource identifier, well-known path and Worker route with that resource before
deployment. Do not advertise an issuer that does not authorize this resource.

Ensure the metadata URL is publicly reachable without an Access session. If the
existing Access application covers it, configure public discovery for this
specific URL without changing policies on protected application routes.

## Test and deploy

From the repository root, using Node.js 20 or newer:

```sh
node --test cloudflare/oauth-protected-resource/worker.test.mjs
```

With Wrangler installed and authenticated to the Cloudflare account owning
`sleeppuzzle.com`, deploy from the Worker directory:

```sh
cd cloudflare/oauth-protected-resource
wrangler deploy --var 'ACCESS_ISSUER:<exact issuer from Access metadata>'
```

Replace the value in angle brackets before running. Alternatively, add the
verified `ACCESS_ISSUER` to `[vars]` in `wrangler.toml` for repeatable deployments;
the issuer is public metadata, not a secret. The Worker returns an uncached 503
when the issuer is missing or invalid, rather than publishing a fabricated one.

The Worker returns 200 JSON for GET, the same headers without a body for HEAD,
and allows anonymous cross-origin discovery. Optional scopes are omitted until
the actual Access configuration establishes supported scopes. The optional
401 `WWW-Authenticate` challenge is owned by Access Managed OAuth; this Worker
does not intercept application requests or invent Bearer challenges for Devise.

## Live validation

```sh
curl --fail --include \
  https://sleeppuzzle.com/.well-known/oauth-protected-resource

curl --fail --silent --show-error https://isitagentready.com/api/scan \
  -H 'Content-Type: application/json' \
  --data '{"url":"https://sleeppuzzle.com"}' > /tmp/sleep-puzzle-agent-scan.json

node --input-type=module -e '
  import fs from "node:fs";
  const scan = JSON.parse(fs.readFileSync("/tmp/sleep-puzzle-agent-scan.json", "utf8"));
  const check = scan.checks.discovery.oauthProtectedResource;
  console.log(JSON.stringify(check, null, 2));
  if (check.status !== "pass") process.exitCode = 1;
'
```

A local test pass does not establish production availability. Record a live
`checks.discovery.oauthProtectedResource.status` of `"pass"` only after deployment.
To roll back, remove this Worker's route in Cloudflare; requests then return to
the existing Rails origin.
