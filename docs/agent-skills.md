# Agent skills discovery

Sleep Puzzle publishes an index following the
[Agent Skills Discovery RFC v0.2.0](https://github.com/cloudflare/agent-skills-discovery-rfc).

- Index: `GET /.well-known/agent-skills/index.json` (`application/json`).
- Artifact: `GET /.well-known/agent-skills/sleep-puzzle-guide/SKILL.md`
  (`text/markdown; charset=utf-8`).
- Both endpoints support HEAD, allow public cross-origin reads, and cache for five
  minutes. They do not require an account or a modern browser.

The skill helps agents navigate the public services and information pages.
Its source is `config/agent_skills/sleep-puzzle-guide/SKILL.md`.
The index description lives in `AgentSkillsController::DESCRIPTION` and must match
the skill's frontmatter. The index calculates the SHA-256 digest from the raw
artifact bytes on each request; no manual hash update is required.

## Verify locally

```sh
bundle exec rspec spec/requests/agent_skills_spec.rb
```

The request tests check the schema, required fields, artifact digest and metadata,
content types, GET/HEAD responses, caching, CORS, and unknown-skill 404 responses.

## Verify production after deployment

```sh
curl --fail-with-body https://isitagentready.com/api/scan \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://sleeppuzzle.com"}' \
  | jq -e '.checks.discovery.agentSkills.status == "pass"'
```

A local test run does not publish the endpoints. Deploy the application before
expecting the public scanner to pass.
