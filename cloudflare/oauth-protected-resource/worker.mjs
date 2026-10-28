const METADATA_PATH = "/.well-known/oauth-protected-resource";
const ALLOW = "GET, HEAD, OPTIONS";

function httpsUrl(value) {
  if (typeof value !== "string" || value.trim() !== value) return null;

  try {
    const url = new URL(value);
    return url.protocol === "https:" && !url.username && !url.password &&
      !url.search && !url.hash ? url : null;
  } catch {
    return null;
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== METADATA_PATH) {
      return new Response(null, { status: 404 });
    }

    const headers = new Headers({
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": ALLOW,
      "Access-Control-Allow-Headers": "Accept",
      "X-Content-Type-Options": "nosniff"
    });

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers });
    }

    if (request.method !== "GET" && request.method !== "HEAD") {
      headers.set("Allow", ALLOW);
      return new Response(null, { status: 405, headers });
    }

    const resource = httpsUrl(env.RESOURCE);
    const issuer = httpsUrl(env.ACCESS_ISSUER);
    // This root well-known document describes the origin, not a path resource.
    // Preserve the issuer exactly: Access issuer identifiers may contain a path.
    if (!resource || env.RESOURCE !== resource.origin || !issuer) {
      headers.set("Cache-Control", "no-store");
      return new Response(null, { status: 503, headers });
    }

    headers.set("Content-Type", "application/json; charset=utf-8");
    headers.set("Cache-Control", "public, max-age=300");
    const metadata = {
      resource: env.RESOURCE,
      authorization_servers: [env.ACCESS_ISSUER]
    };

    return new Response(request.method === "HEAD" ? null : JSON.stringify(metadata), {
      status: 200,
      headers
    });
  }
};
