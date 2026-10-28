# A2A discovery

`GET /.well-known/agent-card.json` serves `config/agent_card.json` as public JSON
with a one-hour cache lifetime. The route is outside the locale scope and does
not require a session or a modern browser.

The card follows the [A2A 1.0 discovery schema](https://a2a-protocol.org/latest/specification/#441-agentcard).
Its advertised `JSONRPC` interface is `POST https://sleeppuzzle.com/a2a`.
The read-only `public-resource-discovery` skill returns a directory of public
resource links in a synchronous message. It does not use an LLM, retain tasks,
access accounts, make purchases, book consultations, stream or send notifications.

Example request:

```sh
curl https://sleeppuzzle.com/a2a \
  -H 'Content-Type: application/json' \
  -H 'A2A-Version: 1.0' \
  -d '{"jsonrpc":"2.0","id":"1","method":"SendMessage","params":{"message":{"messageId":"1","role":"ROLE_USER","parts":[{"text":"Where can I find Sleep Puzzle resources?"}]}}}'
```

Run focused verification:

```sh
bundle exec rspec spec/requests/a2a_spec.rb
bundle exec rubocop app/controllers/a2a_controller.rb config/routes.rb spec/requests/a2a_spec.rb
```

After deploying, check the live discovery scanner:

```sh
curl https://isitagentready.com/api/scan \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://sleeppuzzle.com"}'
```

Check that `checks.discovery.a2aAgentCard.status` is `"pass"`. This scanner checks
the public deployment; it cannot validate unshipped local changes.
