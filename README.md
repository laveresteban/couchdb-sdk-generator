# couchdb-sdk-generator

Turns `couchdb-openapi` into SDKs using
[OpenAPI Generator](https://openapi-generator.tech) (pinned in `openapitools.json`).

| Path | Purpose |
|------|---------|
| `config/<lang>.yaml` | Generator options per language |
| `templates/<lang>/` | Mustache template overrides (optional) |
| `sdk-matrix.yaml` | Spec ref + language → target repo map |
| `scripts/generate.sh` | Local/CI entry point |
| `.github/workflows/generate.yml` | Regenerate and open PRs in SDK repos |

## Local use

Clone the three repos side by side:

```
couchdb-openapi/  couchdb-sdk-generator/  couchdb-python/
```

Then (requires Java 11+ and Node 18+):

```sh
npm install
npm run generate:python
```

## Adding a language

1. Add `config/<lang>.yaml` (see `npx openapi-generator-cli config-help -g <generator>`).
2. Create the `couchdb-<lang>` repo with an `.openapi-generator-ignore` that
   protects hand-written files (tests, CI, CHANGELOG).
3. Add the language to `sdk-matrix.yaml` and the workflow matrix.

## Secrets

- `SDK_BOT_TOKEN`: `contents:write` + `pull_requests:write` on each SDK repo,
  `contents:read` on `couchdb-openapi`.
