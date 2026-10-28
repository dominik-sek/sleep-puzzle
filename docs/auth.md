# Sleep Puzzle auth.md

## Agent audience

This document is for AI agents assisting a person with Sleep Puzzle's public
catalogue, purchases, audio library, or consultation bookings. Public pages can
be read without an account. Account actions use that person's signed-in browser
session and require their authorization.

Sleep Puzzle supports browser account registration through Devise. It does not
provide autonomous agent registration, service accounts, API keys, or bearer
access tokens. Google sign-in is an identity-provider integration, not an OAuth
authorization server operated by Sleep Puzzle. OAuth Protected Resource Metadata
and OAuth Authorization Server metadata are not available for this service.

All endpoint paths below are relative to the origin serving this document. Use
HTTPS in production. Add `?locale=en` to account pages for English.

## Registration methods

### Email and password (browser form)

1. Open [registration](/users/sign_up) with `GET /users/sign_up`.
2. Submit its form to `POST /users` as `application/x-www-form-urlencoded`, using
   `user[email]`, `user[password]`, `user[password_confirmation]`, and the form's
   `authenticity_token`. Passwords must be 6–128 characters and confirmation must
   match. Retain the cookies from the form request for CSRF validation.
3. Successful registration signs the person in through the browser session and
   redirects. Validation failures render the form with errors; correct those
   errors before trying again. This method creates an ordinary customer account,
   with no agent-specific privileges or separate API credential.

For an existing account, open [sign-in](/users/sign_in) with `GET /users/sign_in`
and submit its form to `POST /users/sign_in` with `user[email]`, `user[password]`,
and the current form's `authenticity_token`, retaining cookies as above.

### Google sign-in (interactive browser)

1. Open [registration](/users/sign_up) or [sign-in](/users/sign_in) and let the
   person choose **Continue with Google**.
2. The button submits `POST /users/auth/google_oauth2` with CSRF protection and
   redirects the browser to Google. The person completes Google's sign-in and
   consent flow. Preserve the same browser cookies throughout the flow.
3. Google returns to `GET /users/auth/google_oauth2/callback`. A successful
   callback signs in an existing account matching the email or creates a customer
   account, then establishes the application session. A new Google account has
   no local password until the person sets one in account settings.

This method requires human interaction. Google tokens are not credentials for
calling Sleep Puzzle endpoints.

## Credential use

- Keep the session cookies issued by successful registration or sign-in and send
  them back to the same origin on subsequent browser requests. Treat the cookies
  as secrets; do not put them in URLs or share them with other services.
- Use the browser's HTML forms and current CSRF tokens for state-changing
  requests. These are browser endpoints, not a JSON registration or token API.
  Do not send passwords as HTTP Basic credentials or use an `Authorization:
  Bearer` header: neither is a supported application authentication method.
- The [dashboard](/dashboard) requires sign-in. A session grants the person's
  existing account permissions; purchased audio still requires the corresponding
  purchase, and administrator access requires an administrator account.
- To sign out, submit `DELETE /users/sign_out` with the session cookies and a
  current CSRF token, using the site's sign-out control. Discard local session
  cookies afterwards. There is no agent-token revocation endpoint.
- For password recovery, use [password reset](/users/password/new). Submitting
  the recovery form can send email; only do so when the person requests it.

## Passive discovery

Read this document using `GET /auth.md` or `HEAD /auth.md`. Discovery must not
submit registration, sign-in, or password-recovery forms. There is no
`POST /agent/auth` endpoint; do not probe it. Registration creates accounts,
Google sign-in may provision accounts, and recovery can send email.
