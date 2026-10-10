# couchdb-sdk-generator

Turns [couchdb-openapi](https://github.com/laveresteban/couchdb-openapi) into SDKs
with [OpenAPI Generator](https://openapi-generator.tech) (pinned in
`openapitools.json`). It also holds the **shared Gauge conformance suite** that
every SDK must pass.

```
couchdb-openapi ──tag vX.Y.Z──▶ couchdb-sdk-generator ──PR──▶ couchdb-python (CI: pytest + Gauge)
                                                     └─PR──▶ couchdb-node   (CI: vitest + Gauge)
```

couchdb-android is hand-written (see [docs/android-offline-sync.md](docs/android-offline-sync.md))
but runs the same conformance specs.

| Path | Purpose |
|------|---------|
| `config/<lang>.yaml` | Generator options per language |
| `templates/<lang>/` | Mustache template overrides (see each README) |
| `conformance/specs/` | Cross-language Gauge scenarios ([README](conformance/README.md)) |
| `sdk-matrix.json` | Default spec ref, and per language: config, SDK repo, output dir, post step |
| `scripts/generate.sh` | Local/CI entry point (reads `sdk-matrix.json`) |
| `.github/workflows/generate.yml` | Regenerate and open PRs in SDK repos (matrix from `sdk-matrix.json`) |
| `.github/workflows/sdk-ci.yml` | Reusable CI the generated SDKs call: tests, conformance, generated-code drift check |
| `docs/sdk-design.md` | How the hand-written SDK layers behave (errors, retries, changes feed, sessions, parity) |
| `.github/workflows/ci.yml` | Every language generates from couchdb-openapi `main`; specs parse; Docker runners work |
| `scripts/check-specs.sh` | Parses the conformance specs and checks their conventions |
| `docker-compose.yml` | CouchDB plus a conformance runner per SDK |

## Local use

Clone the repos side by side:

```
couchdb-openapi/  couchdb-sdk-generator/  couchdb-python/  couchdb-node/  couchdb-android/
```

Then (requires Java 11+ and Node 18+):

```sh
npm ci
npm run generate:python     # same as: bash scripts/generate.sh python
npm run generate:node       # same as: bash scripts/generate.sh typescript
```

Conformance against a throwaway CouchDB, with only Docker installed:

```sh
docker compose run --rm gauge-python    # or gauge-node, gauge-android
```

**Versioning:** `generate.sh` reads `info.version` from the spec and passes
it as the package version, so SDK releases track spec releases. It also
deletes files the generator wrote last time but no longer writes (models for
removed schemas), since OpenAPI Generator never deletes anything. It also
writes `.generated-from` (spec version, spec commit, generator commit,
OpenAPI Generator version) into the SDK repo.

## Adding a language

1. Add `config/<lang>.yaml` (`npx openapi-generator-cli config-help -g <generator>`).
2. Create `couchdb-<lang>` with an `.openapi-generator-ignore` that protects
   hand-written files (tests, CI, the idiomatic layer, `conformance/`), or
   generate into a subdirectory (`output`) so nothing else is touched.
3. Implement the Gauge steps for that language (see `conformance/README.md`).
4. Add the language to `sdk-matrix.json` (`config`, `repo`, `output`, and an
   optional `post` command run in the SDK repo). Both workflows pick it up.
5. Give the SDK repo a `ci.yml` that calls `sdk-ci.yml` (see its header),
   and follow `docs/sdk-design.md` for the hand-written layer.

### Choosing a generator per language

OpenAPI Generator is the default because one tool covers every language.
Swap it per language when a dedicated generator is clearly better, e.g.
`openapi-python-client` (attrs + httpx, native async) or `oapi-codegen` for Go.
The SDK's hand-written layer and the conformance suite insulate users from
that swap.

### Spec patterns to avoid (they generate broken code)

Found while building the Python SDK. Keep `couchdb-openapi` clear of these:

- **`enum` inside `additionalProperties`** (e.g. a `{field: "asc"|"desc"}` map):
  the Python generator validates the whole dict against the enum.
- **Untyped `{}` properties** (e.g. view `start_key`): stock Python `from_dict`
  marks absent fields as set, so they go out as `null`, and CouchDB treats
  `end_key: null` as a real bound (0 rows). Fixed for Python by
  `templates/python/model_generic.mustache`; other languages should check
  for the same problem.
- **`oneOf` with a primitive** (e.g. `oneOf: [string, object]`):
  typescript-fetch imports a `./string` model that doesn't exist. Leave the
  schema untyped with a description instead (see `ReplicationEndpoint`).
- **Open documents (`additionalProperties: true` on `Document`)** with the
  Kotlin generator + kotlinx-serialization: the model becomes a `HashMap`
  subclass and user fields are lost. `couchdb-android` uses a hand-written
  client for document and replication calls for this reason.

## Secrets

See [SETUP.md](SETUP.md).

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
